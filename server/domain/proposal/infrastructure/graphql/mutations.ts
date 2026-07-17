import { match, P } from 'ts-pattern'
import type { EditedDraft } from '~/domain/proposal/use-case'
import { ProposalUseCase } from '~/domain/proposal/use-case'
import { toTmxSettings } from '~/domain/recipe/business-rules'
import { RecipeType } from '~/domain/recipe/infrastructure/graphql/types'
import type { Recipe, VersionNumber } from '~/domain/recipe/types'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError, notFound } from '~/domain/shared/graphql/errors'
import { ProposalDraftInput } from './inputs'
import { ProposalType } from './types'

type AcceptResult = {
  recipe: Recipe
  createdVersion: VersionNumber | null
}

const AcceptProposalResultType = builder.objectRef<AcceptResult>('AcceptProposalResult').implement({
  description: 'Result of accepting a proposal as an iteration',
  fields: (t) => ({
    recipe: t.field({ type: RecipeType, resolve: (r) => r.recipe }),
    createdVersion: t.expose('createdVersion', { type: 'VersionNumber', nullable: true }),
  }),
})

builder.mutationField('requestProposal', (t) =>
  t.field({
    type: ProposalType,
    description: 'Ask the AI to analyze the latest trials and propose the next iteration',
    args: { recipeId: t.arg({ type: 'RecipeId', required: true }) },
    resolve: async (_root, { recipeId }, { userId }) => {
      const result = await ProposalUseCase.proposeFromTrial(userId, recipeId)
      return match(result)
        .with('not-found', () => notFound('Recipe not found'))
        .with(P.not(P.string), (proposal) => proposal)
        .exhaustive()
    },
  }),
)

builder.mutationField('acceptProposal', (t) =>
  t.field({
    type: AcceptProposalResultType,
    description: 'Accept a proposal as an iteration (optionally editing the draft first)',
    args: {
      recipeId: t.arg({ type: 'RecipeId', required: true }),
      versionNumber: t.arg({ type: 'VersionNumber', required: true }),
      editedDraft: t.arg({
        type: ProposalDraftInput,
        description: 'The edited next-version draft, replacing the AI proposal when provided',
      }),
    },
    resolve: async (_root, args, { userId }) => {
      const editedDraft: EditedDraft | undefined = args.editedDraft
        ? {
            ingredients: args.editedDraft.ingredients,
            steps: args.editedDraft.steps,
            tmxSteps: args.editedDraft.tmxSteps ? toTmxSettings(args.editedDraft.tmxSteps) : [],
          }
        : undefined
      const result = await ProposalUseCase.acceptAsIteration(
        userId,
        args.recipeId,
        args.versionNumber,
        editedDraft,
      )
      const recipe = ensureRecipe(result)
      return { recipe, createdVersion: recipe.toTest }
    },
  }),
)

builder.mutationField('refuseProposal', (t) =>
  t.field({
    type: 'Boolean',
    description: 'Refuse a proposal (removes it)',
    args: {
      recipeId: t.arg({ type: 'RecipeId', required: true }),
      versionNumber: t.arg({ type: 'VersionNumber', required: true }),
    },
    resolve: async (_root, { recipeId, versionNumber }, _ctx) => {
      await ProposalUseCase.refuse(recipeId, versionNumber)
      return true
    },
  }),
)

// Turn the use-case's discriminated error strings into GraphQL errors.
const ensureRecipe = (result: Recipe | 'not-found' | 'no-proposal') =>
  match(result)
    .with('not-found', () => notFound('Recipe not found'))
    .with('no-proposal', () => domainError('NO_PROPOSAL', 'No pending proposal for this version'))
    .with(P.not(P.string), (recipe) => recipe)
    .exhaustive()
