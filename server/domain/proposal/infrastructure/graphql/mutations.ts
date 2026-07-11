import { GraphQLError } from 'graphql'
import { ProposalUseCase } from '~/domain/proposal/use-case'
import { RecipeType } from '~/domain/recipe/infrastructure/graphql/types'
import type { Recipe, RecipeId, VersionNumber } from '~/domain/recipe/types'
import { builder } from '~/domain/shared/graphql/builder'
import { ProposalRecommendationEnum } from './enums'
import { ProposalVarInput } from './inputs'
import { ProposalType } from './types'

type AcceptResult = {
  recipe: Recipe
  createdVersion: VersionNumber | null
  createdRecipeId: RecipeId | null
}

const AcceptProposalResultType = builder.objectRef<AcceptResult>('AcceptProposalResult').implement({
  description: 'Result of accepting a proposal (an iteration or a variation)',
  fields: (t) => ({
    recipe: t.field({ type: RecipeType, resolve: (r) => r.recipe }),
    createdVersion: t.expose('createdVersion', { type: 'VersionNumber', nullable: true }),
    createdRecipeId: t.expose('createdRecipeId', { type: 'RecipeId', nullable: true }),
  }),
})

const notFound = () => new GraphQLError('Recipe not found', { extensions: { code: 'NOT_FOUND' } })

builder.mutationField('requestProposal', (t) =>
  t.field({
    type: ProposalType,
    description:
      'Ask the AI to analyze the latest trials and propose the next step (iterate or vary)',
    args: { recipeId: t.arg({ type: 'RecipeId', required: true }) },
    resolve: async (_root, { recipeId }, { userId }) => {
      const result = await ProposalUseCase.proposeFromTrial(userId, recipeId)
      if (result === 'not-found') throw notFound()
      return result
    },
  }),
)

builder.mutationField('acceptProposal', (t) =>
  t.field({
    type: AcceptProposalResultType,
    description:
      'Accept a proposal as an iteration or a variation (optionally editing the changes)',
    args: {
      recipeId: t.arg({ type: 'RecipeId', required: true }),
      versionNumber: t.arg({ type: 'VersionNumber', required: true }),
      choice: t.arg({ type: ProposalRecommendationEnum, required: true }),
      editedVars: t.arg({ type: [ProposalVarInput] }),
    },
    resolve: async (_root, args, { userId }) => {
      const edited = args.editedVars?.map((v) => ({ key: v.key, from: v.from ?? null, to: v.to }))
      if (args.choice === 'iteration') {
        const result = await ProposalUseCase.acceptAsIteration(
          userId,
          args.recipeId,
          args.versionNumber,
          edited,
        )
        const recipe = ensureRecipe(result)
        return { recipe, createdVersion: recipe.toTest, createdRecipeId: null }
      }
      const result = await ProposalUseCase.acceptAsVariation(
        userId,
        args.recipeId,
        args.versionNumber,
        edited,
      )
      const recipe = ensureRecipe(result)
      return { recipe, createdVersion: null, createdRecipeId: recipe.id }
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
const ensureRecipe = (result: Recipe | string): Recipe => {
  if (result === 'not-found') throw notFound()
  if (result === 'no-proposal')
    throw new GraphQLError('No pending proposal for this version', {
      extensions: { code: 'NO_PROPOSAL' },
    })
  if (result === 'budget-exceeded')
    throw new GraphQLError('Too many variables for this recipe type', {
      extensions: { code: 'BUDGET_EXCEEDED' },
    })
  return result as Recipe
}
