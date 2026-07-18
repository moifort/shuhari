import { match, P } from 'ts-pattern'
import type { AcceptedDraft } from '~/domain/draft/types'
import { DraftUseCase } from '~/domain/draft/use-case'
import { toTmxSettings } from '~/domain/recipe/business-rules'
import { RecipeType } from '~/domain/recipe/infrastructure/graphql/types'
import type { Recipe, VersionNumber } from '~/domain/recipe/types'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError } from '~/domain/shared/graphql/errors'
import { DraftInput } from './inputs'
import { DraftType } from './types'

type AcceptResult = {
  recipe: Recipe
  createdVersion: VersionNumber | null
}

const AcceptDraftResultType = builder.objectRef<AcceptResult>('AcceptDraftResult').implement({
  description: 'What you get back after accepting an AI suggestion',
  fields: (t) => ({
    recipe: t.field({
      type: RecipeType,
      description: 'The recipe, now with the accepted version added to its chain',
      resolve: (r) => r.recipe,
    }),
    createdVersion: t.expose('createdVersion', {
      type: 'VersionNumber',
      nullable: true,
      description: 'The number of the version that was just created and queued up to try',
    }),
  }),
})

builder.mutationField('requestDraft', (t) =>
  t.field({
    type: DraftType,
    description:
      'Ask the AI for a suggested next version. It looks at your most recent attempt (its rating ' +
      'and notes) and proposes one improvement. Nothing is saved yet — you get a proposal to ' +
      'review.',
    args: {
      recipeId: t.arg({
        type: 'RecipeId',
        required: true,
        description: 'The recipe to get a suggestion for',
      }),
    },
    resolve: async (_root, { recipeId }, { userId }) => {
      const result = await DraftUseCase.forTrial(userId, recipeId)
      return match(result)
        .with('not-found', domainError)
        .with(P.not(P.string), (draft) => draft)
        .exhaustive()
    },
  }),
)

builder.mutationField('acceptDraft', (t) =>
  t.field({
    type: AcceptDraftResultType,
    description:
      'Accept an AI suggestion (optionally after editing it). It becomes the next version in the ' +
      'chain, added to your to-do list of attempts to cook.',
    args: {
      recipeId: t.arg({
        type: 'RecipeId',
        required: true,
        description: 'The recipe being iterated on',
      }),
      draft: t.arg({
        type: DraftInput,
        required: true,
        description: 'The full suggested version to save (with any edits you made)',
      }),
    },
    resolve: async (_root, { recipeId, draft }, { userId }) => {
      const accepted: AcceptedDraft = {
        changeSummary: draft.changeSummary,
        rationale: draft.rationale,
        ingredients: draft.ingredients,
        steps: draft.steps,
        tmxSteps: draft.tmxSteps ? toTmxSettings(draft.tmxSteps) : [],
      }
      const result = await DraftUseCase.accept(userId, recipeId, accepted)
      const recipe = ensureRecipe(result)
      return { recipe, createdVersion: recipe.toTest }
    },
  }),
)

// Turn the use-case's discriminated error strings into GraphQL errors.
const ensureRecipe = (result: Recipe | 'not-found') =>
  match(result)
    .with('not-found', domainError)
    .with(P.not(P.string), (recipe) => recipe)
    .exhaustive()
