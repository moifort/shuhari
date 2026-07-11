import * as repository from '~/domain/recipe/infrastructure/repository'
import type { RecipeId, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'

export namespace RecipeQuery {
  export const all = async (userId: UserId) => repository.findAllByUser(userId)

  export const byId = async (userId: UserId, id: RecipeId) => {
    const recipe = await repository.findBy(userId, id)
    if (!recipe) return 'not-found' as const
    return recipe
  }

  export const byIds = async (userId: UserId, ids: RecipeId[]) =>
    repository.findManyByIds(userId, ids)

  export const versionsOf = async (recipeId: RecipeId) => repository.findVersionsOf(recipeId)

  export const allVersions = async (userId: UserId) => repository.findAllVersionsByUser(userId)

  export const versionBy = async (recipeId: RecipeId, number: VersionNumber) => {
    const version = await repository.findVersion(recipeId, number)
    if (!version) return 'not-found' as const
    return version
  }

  export const versionsByRefs = async (refs: { recipeId: RecipeId; number: VersionNumber }[]) =>
    repository.findVersionsByRefs(refs)

  export const variationsOf = async (userId: UserId, recipeId: RecipeId) =>
    repository.findVariationsOf(userId, recipeId)
}
