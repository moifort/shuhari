import { GraphQLError } from 'graphql'
import { match, P } from 'ts-pattern'
import type { AcceptedProposal } from '~/domain/proposal/types'
import { ProposalUseCase } from '~/domain/proposal/use-case'
import { toTmxSettings } from '~/domain/recipe/business-rules'
import { RecipeType } from '~/domain/recipe/infrastructure/graphql/types'
import type { Recipe, VersionNumber } from '~/domain/recipe/types'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError } from '~/domain/shared/graphql/errors'
import { imageWithinSizeLimit, MAX_IMPORT_PHOTOS } from '~/system/ai/limits'
import type { ImportSource } from '~/system/ai/types'
import { ProposalInput } from './inputs'
import { ImportAnalysisType, ProposalType } from './types'

type AcceptResult = {
  recipe: Recipe
  createdVersion: VersionNumber | null
}

const AcceptProposalResultType = builder.objectRef<AcceptResult>('AcceptProposalResult').implement({
  description:
    'What you get back after accepting an AI suggestion, e.g. the new `v3` added to the chain',
  fields: (t) => ({
    recipe: t.field({
      type: RecipeType,
      description:
        'The recipe, now with the accepted version added to its chain, e.g. ' +
        '`"Grandma’s lasagna"` now up to `v3`',
      resolve: (r) => r.recipe,
    }),
    createdVersion: t.expose('createdVersion', {
      type: 'VersionNumber',
      nullable: true,
      description: 'The number of the version that was just created, e.g. `3`',
    }),
  }),
})

builder.mutationField('requestProposal', (t) =>
  t.field({
    type: ProposalType,
    description: [
      'Ask the AI for a suggested next version. It looks at the version you just cooked (its ' +
        'rating and notes) and proposes one improvement. Nothing is saved yet — you get a ' +
        'proposal to review.',
      '',
      '```graphql',
      'requestProposal(recipeId: "9f1c-a3b2", versionNumber: 2) {',
      '  basedOn',
      '  changeSummary',
      '  rationale',
      '}',
      '```',
    ].join('\n'),
    args: {
      recipeId: t.arg({
        type: 'RecipeId',
        required: true,
        description: 'The recipe to get a suggestion for, e.g. the id of `"Grandma’s lasagna"`',
      }),
      versionNumber: t.arg({
        type: 'VersionNumber',
        required: true,
        description: 'The version you just cooked and want to iterate on, e.g. `2`',
      }),
    },
    resolve: async (_root, { recipeId, versionNumber }, { userId }) => {
      const result = await ProposalUseCase.fromEssai(userId, recipeId, versionNumber)
      return match(result)
        .with('not-found', domainError)
        .with(P.not(P.string), (proposal) => proposal)
        .exhaustive()
    },
  }),
)

builder.mutationField('acceptProposal', (t) =>
  t.field({
    type: AcceptProposalResultType,
    description: [
      'Accept an AI suggestion (optionally after editing it). It becomes the next version in ' +
        'the chain, ready to cook.',
      '',
      '```graphql',
      'acceptProposal(recipeId: "9f1c-a3b2", proposal: {',
      '  basedOn: 2',
      '  changeSummary: "Less sugar"',
      '  rationale: "You noted it was too sweet"',
      '  ingredients: [{ name: "Sugar", quantity: "80 g" }]',
      '  steps: ["Rest the dough for 2 h", "Bake at 180°C"]',
      '}) {',
      '  createdVersion',
      '}',
      '```',
    ].join('\n'),
    args: {
      recipeId: t.arg({
        type: 'RecipeId',
        required: true,
        description: 'The recipe being iterated on, e.g. the id of `"Grandma’s lasagna"`',
      }),
      proposal: t.arg({
        type: ProposalInput,
        required: true,
        description: 'The full suggested version to save (with any edits you made)',
      }),
    },
    resolve: async (_root, { recipeId, proposal }, { userId }) => {
      const accepted: AcceptedProposal = {
        basedOn: proposal.basedOn,
        changeSummary: proposal.changeSummary,
        rationale: proposal.rationale,
        ingredients: proposal.ingredients,
        steps: proposal.steps,
        tmxSteps: proposal.tmxSteps ? toTmxSettings(proposal.tmxSteps) : [],
      }
      const result = await ProposalUseCase.accept(userId, recipeId, accepted)
      const recipe = ensureRecipe(result)
      // addVersion appends n+1 and bumps versionCount to it, so the newly created
      // version is the recipe's latest (highest) number.
      return { recipe, createdVersion: recipe.versionCount }
    },
  }),
)

const badInput = (message: string) =>
  new GraphQLError(message, { extensions: { code: 'BAD_USER_INPUT' } })

builder.mutationField('analyzeImport', (t) =>
  t.field({
    type: ImportAnalysisType,
    description:
      'Analyze an import source (photos, a URL or raw text) into a structured recipe preview. Exactly one source must be provided. Results are cached server-side by SHA-256.',
    args: {
      photos: t.arg.stringList({ description: 'Base64 JPEGs (no data-URL prefix)' }),
      url: t.arg.string({ description: 'A recipe web page to read' }),
      text: t.arg.string({ description: 'Raw recipe text' }),
    },
    resolve: async (_root, { photos, url, text }, { userId }) => {
      const source = pickSource(photos, url, text)
      let result: Awaited<ReturnType<typeof ProposalUseCase.fromPhoto>>
      try {
        result = await ProposalUseCase.fromPhoto(userId, source)
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Import analysis failed'
        throw new GraphQLError(message, { extensions: { code: 'IMPORT_FAILED' } })
      }
      return match(result)
        .with('no-recipe-found', domainError)
        .with(P.not(P.string), (analysis) => analysis)
        .exhaustive()
    },
  }),
)

const pickSource = (
  photos: string[] | null | undefined,
  url: string | null | undefined,
  text: string | null | undefined,
): ImportSource => {
  const provided = [
    photos?.length ? 'photos' : null,
    url ? 'url' : null,
    text ? 'text' : null,
  ].filter(Boolean)
  if (provided.length !== 1) throw badInput('Provide exactly one of photos, url or text')
  if (photos?.length) {
    if (photos.length > MAX_IMPORT_PHOTOS)
      throw badInput(`At most ${MAX_IMPORT_PHOTOS} photos are allowed`)
    if (!photos.every((photo) => imageWithinSizeLimit(photo.length)))
      throw badInput('A photo exceeds the 10 MB size limit')
    return { kind: 'photos', photos }
  }
  if (url) return { kind: 'url', url }
  return { kind: 'text', text: text as string }
}

// Turn the use-case's discriminated error strings into GraphQL errors.
const ensureRecipe = (result: Recipe | 'not-found') =>
  match(result)
    .with('not-found', domainError)
    .with(P.not(P.string), (recipe) => recipe)
    .exhaustive()
