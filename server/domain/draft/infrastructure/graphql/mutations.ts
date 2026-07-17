import { match, P } from 'ts-pattern'
import type { AcceptedDraft } from '~/domain/draft/types'
import { DraftUseCase } from '~/domain/draft/use-case'
import { toTmxSettings } from '~/domain/recipe/business-rules'
import { RecipeType } from '~/domain/recipe/infrastructure/graphql/types'
import type { Recipe, VersionNumber } from '~/domain/recipe/types'
import { builder } from '~/domain/shared/graphql/builder'
import { notFound } from '~/domain/shared/graphql/errors'
import { DraftInput } from './inputs'
import { DraftType } from './types'

type AcceptResult = {
  recipe: Recipe
  createdVersion: VersionNumber | null
}

const AcceptDraftResultType = builder.objectRef<AcceptResult>('AcceptDraftResult').implement({
  description: 'Result of accepting a draft as an iteration',
  fields: (t) => ({
    recipe: t.field({ type: RecipeType, resolve: (r) => r.recipe }),
    createdVersion: t.expose('createdVersion', { type: 'VersionNumber', nullable: true }),
  }),
})

builder.mutationField('requestDraft', (t) =>
  t.field({
    type: DraftType,
    description: 'Ask the AI to analyze the latest trials and draft the next iteration',
    args: { recipeId: t.arg({ type: 'RecipeId', required: true }) },
    resolve: async (_root, { recipeId }, { userId }) => {
      const result = await DraftUseCase.forTrial(userId, recipeId)
      return match(result)
        .with('not-found', () => notFound('Recipe not found'))
        .with(P.not(P.string), (draft) => draft)
        .exhaustive()
    },
  }),
)

builder.mutationField('acceptDraft', (t) =>
  t.field({
    type: AcceptDraftResultType,
    description: 'Accept a draft as an iteration, appending it as the next version to test',
    args: {
      recipeId: t.arg({ type: 'RecipeId', required: true }),
      draft: t.arg({ type: DraftInput, required: true }),
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
    .with('not-found', () => notFound('Recipe not found'))
    .with(P.not(P.string), (recipe) => recipe)
    .exhaustive()
