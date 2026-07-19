import { RecipeCommand } from '~/domain/recipe/command'
import type { RecipeId } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'

export namespace RecipeUseCase {
  // Delete a recipe and everything attached to it. Its versions (each carrying its
  // own attempt outcome) cascade with the recipe command; AI proposals are
  // ephemeral, so there is nothing else to cascade.
  export const removeCompletely = async (userId: UserId, recipeId: RecipeId) => {
    const result = await RecipeCommand.remove(userId, recipeId)
    if (result === 'not-found') return 'not-found'
    return undefined
  }
}
