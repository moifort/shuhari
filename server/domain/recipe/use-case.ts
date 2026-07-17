import { RecipeCommand } from '~/domain/recipe/command'
import type { RecipeId } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { TrialCommand } from '~/domain/trial/command'

export namespace RecipeUseCase {
  // Delete a recipe and everything attached to it: its versions (recipe command)
  // and its trials. AI drafts are ephemeral, so there is nothing else to cascade.
  export const removeCompletely = async (userId: UserId, recipeId: RecipeId) => {
    const result = await RecipeCommand.remove(userId, recipeId)
    if (result === 'not-found') return 'not-found'
    await TrialCommand.removeByRecipe(userId, recipeId)
    return undefined
  }
}
