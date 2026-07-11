import { ProposalCommand } from '~/domain/proposal/command'
import { RecipeCommand } from '~/domain/recipe/command'
import type { RecipeId } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { TrialCommand } from '~/domain/trial/command'

export namespace RecipeUseCase {
  // Delete a recipe and everything attached to it: its versions (recipe command),
  // its trials, and any pending proposals.
  export const removeCompletely = async (
    userId: UserId,
    recipeId: RecipeId,
  ): Promise<undefined | 'not-found'> => {
    const result = await RecipeCommand.remove(userId, recipeId)
    if (result === 'not-found') return 'not-found'
    await Promise.all([
      TrialCommand.removeByRecipe(userId, recipeId),
      ProposalCommand.removeByRecipe(userId, recipeId),
    ])
    return undefined
  }
}
