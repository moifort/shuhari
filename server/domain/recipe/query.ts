import * as repository from '~/domain/recipe/infrastructure/repository'
import type {
  DishCategory,
  Recipe,
  RecipeId,
  RecipeSort,
  RecipeType,
  SortOrder,
  VersionNumber,
} from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'

// One page of the recipe library plus the pagination signals. `totalCount` is the
// size of this page (the full count is never computed — see the GraphQL type).
export type RecipeLibraryPage = { items: Recipe[]; hasMore: boolean; totalCount: number }

export type RecipeLibraryCriteria = {
  type?: RecipeType
  category?: DishCategory
  sort: RecipeSort
  order: SortOrder
  limit: number
  after?: RecipeId
}

// The library page never returns more than this many recipes at once, whatever a
// client requests — an infinite-scroll page, not a full dump.
const MAX_LIMIT = 50
const clampLimit = (limit: number) => Math.max(1, Math.min(MAX_LIMIT, Math.trunc(limit)))

export namespace RecipeQuery {
  export const all = async (userId: UserId) => repository.findAllByUser(userId)

  // A page of the user's recipe library, filtered by type and sorted per the view.
  export const library = async (
    userId: UserId,
    criteria: RecipeLibraryCriteria,
  ): Promise<RecipeLibraryPage> => {
    // A category filter pins the order to updatedAt desc: ranking recipes within
    // a single course is meaningless, and coercing here keeps the composite-index
    // surface bounded (no per-category × sort index explosion).
    const effective: RecipeLibraryCriteria = criteria.category
      ? { ...criteria, sort: 'updatedAt', order: 'desc' }
      : criteria
    const { recipes, hasMore } = await repository.findPage(userId, {
      ...effective,
      limit: clampLimit(effective.limit),
    })
    return { items: recipes, hasMore, totalCount: recipes.length }
  }

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
