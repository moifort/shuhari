import type { RecipeId, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import * as repository from '~/domain/trial/infrastructure/repository'
import type { TrialId } from '~/domain/trial/types'

export namespace TrialQuery {
  export const all = async (userId: UserId) => repository.findAllByUser(userId)

  export const byRecipe = async (userId: UserId, recipeId: RecipeId) =>
    (await repository.findAllByUser(userId)).filter((trial) => trial.recipeId === recipeId)

  export const byVersion = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumber,
  ) =>
    (await repository.findAllByUser(userId)).filter(
      (trial) => trial.recipeId === recipeId && trial.versionNumber === versionNumber,
    )

  export const recent = async (userId: UserId, limit: number) =>
    (await repository.findAllByUser(userId)).slice(0, limit)

  export const byRecipeIds = async (userId: UserId, recipeIds: RecipeId[]) => {
    const wanted = new Set(recipeIds)
    return (await repository.findAllByUser(userId)).filter((trial) => wanted.has(trial.recipeId))
  }

  export const byId = async (userId: UserId, id: TrialId) => {
    const trial = await repository.findById(userId, id)
    if (!trial) return 'not-found' as const
    return trial
  }
}
