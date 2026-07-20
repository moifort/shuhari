import { nextVersionNumber } from '~/domain/recipe/business-rules'
import type { VersionContent } from '~/domain/recipe/content/types'
import * as repository from '~/domain/recipe/infrastructure/repository'
import { randomRecipeId, VersionNumber } from '~/domain/recipe/primitives'
import type {
  DishCategory,
  Rating,
  Recipe,
  RecipeId,
  RecipeTitle,
  RecipeType,
  RecipeVersion,
  Remarks,
  VersionNumber as VersionNumberT,
  VersionOrigin,
} from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { atomically, bulkSave } from '~/utils/firestore'

const FIRST_VERSION = VersionNumber(1)

export type NewRecipeInput = {
  type: RecipeType
  category: DishCategory
  title: RecipeTitle
  content: VersionContent
}

// The cook that produced a version: the rating, remarks and photo of the attempt
// whose remarks the AI answered. It rides along with the version it gave birth to.
export type Attempt = {
  rating: Rating
  remarks: Remarks
  photoPath?: string
}

export type NewVersionInput = {
  change: string
  basedOn?: VersionNumberT
  why?: string
  content: VersionContent
  // The attempt that produced this version — absent when an improvement asked for it
  // instead, in which case the version created is one to test.
  attempt?: Attempt
}

// What can be retouched on the aggregate after creation. Anything left out stays as
// it was; `favorite: false` un-favourites.
export type UpdateRecipeInput = {
  title?: RecipeTitle
  category?: DishCategory
  favorite?: boolean
}

export type RecordAttemptInput = {
  recipeId: RecipeId
  versionNumber: VersionNumberT
  rating: Rating
  // Absent when the cook was rated without a word written about it — a bare rating
  // ends the flow, it never asks the AI for anything.
  remarks?: Remarks
  photoPath?: string
}

export namespace RecipeCommand {
  // Create → recipe + its v1, written atomically. v1 is the original planned attempt
  // (no `basedOn`, it iterates on nothing) and awaits its first cook.
  export const create = async (userId: UserId, input: NewRecipeInput, sourceLabel?: string) => {
    // The body's discriminant must mirror the recipe type — a dish recipe cannot
    // carry Thermomix content and vice versa. Enforced here, no throw.
    if (input.content.kind !== input.type) return 'content-type-mismatch' as const
    const now = new Date()
    const recipe: Recipe = {
      id: randomRecipeId(),
      userId,
      type: input.type,
      category: input.category,
      title: input.title,
      versionCount: FIRST_VERSION,
      createdAt: now,
      updatedAt: now,
    }
    const origin: VersionOrigin = {
      kind: 'import',
      ...(sourceLabel ? { detail: sourceLabel } : {}),
    }
    return atomically(async (batch) => {
      await repository.save(recipe, batch)
      await repository.saveVersion(firstVersion(recipe, origin, input), batch)
      return recipe
    })
  }

  // Accepted AI iteration → append version n+1 to the lineage, stamping the version
  // it was proposed from (`basedOn`). No reference/pending pointer to maintain: the
  // recipe just bumps its `versionCount` and `updatedAt`. The attempt that asked for
  // this version lands on it, never on the version it iterates on — that one only
  // loses its `toTest` flag, since the cook that answers it is the cook it owed.
  // Born of an improvement instead (no attempt), the version is the one waiting to be
  // cooked: it is the sole way a version becomes `toTest`.
  export const addVersion = async (userId: UserId, recipeId: RecipeId, input: NewVersionInput) => {
    const recipe = await repository.findBy(userId, recipeId)
    if (!recipe) return 'not-found' as const
    // The body's discriminant must mirror the recipe type (see `create`).
    if (input.content.kind !== recipe.type) return 'content-type-mismatch' as const
    const number = nextVersionNumber(recipe.versionCount)
    const version: RecipeVersion = {
      userId,
      recipeId,
      number,
      createdAt: new Date(),
      origin: { kind: 'ai-proposal' },
      change: input.change,
      ...(input.basedOn !== undefined ? { basedOn: input.basedOn } : {}),
      ...(input.why ? { why: input.why } : {}),
      content: input.content,
      // The outcome of the attempt that produced it, when there was one; without it
      // the version is what the cook asked for and still owes a try.
      ...(input.attempt
        ? {
            executedAt: new Date(),
            rating: input.attempt.rating,
            remarks: input.attempt.remarks,
            ...(input.attempt.photoPath ? { photoPath: input.attempt.photoPath } : {}),
          }
        : { toTest: true as const }),
    }
    const updated: Recipe = {
      ...recipe,
      versionCount: number,
      updatedAt: new Date(),
    }
    // The version this one answers has been cooked: it owes nothing anymore.
    const cooked = input.attempt ? await cookedBase(recipeId, input.basedOn) : undefined
    return atomically(async (batch) => {
      await repository.saveVersion(version, batch)
      if (cooked) await repository.saveVersion(cooked, batch)
      await repository.save(updated, batch)
      return updated
    })
  }

  // Record the attempt outcome onto a version — the cook that asks for nothing more
  // (a rating, maybe a photo, no remarks). Overwritable: re-cooking the same version
  // simply rewrites its rating/remarks/executedAt in place. The outcome and the
  // recipe's `updatedAt` bump land in one batch (all-or-nothing).
  export const recordAttempt = async (
    userId: UserId,
    input: RecordAttemptInput,
  ): Promise<RecipeVersion | 'not-found'> => {
    const recipe = await repository.findBy(userId, input.recipeId)
    if (!recipe) return 'not-found' as const
    const version = await repository.findVersion(input.recipeId, input.versionNumber)
    if (!version) return 'not-found' as const
    // Drop the previous photo and remarks before spreading: a re-cook that leaves
    // them out must erase what the earlier attempt left behind, not inherit it. The
    // `toTest` flag goes too — the version has just been cooked.
    const {
      photoPath: _replacedPhoto,
      remarks: _replacedRemarks,
      toTest: _cooked,
      ...rest
    } = version
    const executed: RecipeVersion = {
      ...rest,
      executedAt: new Date(),
      rating: input.rating,
      ...(input.remarks ? { remarks: input.remarks } : {}),
      ...(input.photoPath ? { photoPath: input.photoPath } : {}),
    }
    const updatedRecipe: Recipe = { ...recipe, updatedAt: new Date() }
    return atomically(async (batch) => {
      await repository.saveVersion(executed, batch)
      await repository.save(updatedRecipe, batch)
      return executed
    })
  }

  // The touches a cook can make to the aggregate itself: its name, its course and
  // whether it is a favourite. Each is optional — what is left out stays as it was.
  // `favorite: false` drops the field entirely (the full-document write erases it),
  // so absence is the single spelling of "not a favourite". A category change keeps
  // the library's sort honest on its own: `repository.save` re-derives `categoryRank`.
  export const update = async (userId: UserId, recipeId: RecipeId, input: UpdateRecipeInput) => {
    const recipe = await repository.findBy(userId, recipeId)
    if (!recipe) return 'not-found' as const
    // Spread without the flag, then put it back only if it holds — otherwise the
    // rewritten document simply has no `favorite` field.
    const { favorite: _dropped, ...rest } = recipe
    const favorite = input.favorite ?? recipe.favorite === true
    const updated: Recipe = {
      ...rest,
      ...(input.title ? { title: input.title } : {}),
      ...(input.category ? { category: input.category } : {}),
      ...(favorite ? { favorite: true as const } : {}),
      updatedAt: new Date(),
    }
    return repository.save(updated)
  }

  export const remove = async (userId: UserId, recipeId: RecipeId) => {
    const recipe = await repository.findBy(userId, recipeId)
    if (!recipe) return 'not-found' as const
    await repository.remove(recipeId)
    return undefined
  }

  // Portability: wipe and restore the user's recipes and versions.
  export const replaceAllForUser = async (
    userId: UserId,
    recipes: Recipe[],
    versions: RecipeVersion[],
  ) => {
    await repository.removeAllByUser(userId)
    await bulkSave(recipes, (recipe) => repository.save(recipe))
    await bulkSave(versions, (version) => repository.saveVersion(version))
  }

  // The version an attempt-born iteration is based on, stripped of its `toTest` flag —
  // or nothing when there is no base, or it was not waiting to be cooked.
  const cookedBase = async (recipeId: RecipeId, basedOn?: VersionNumberT) => {
    if (basedOn === undefined) return undefined
    const base = await repository.findVersion(recipeId, basedOn)
    if (!base?.toTest) return undefined
    const { toTest: _cooked, ...rest } = base
    return rest
  }

  const firstVersion = (
    recipe: Recipe,
    origin: VersionOrigin,
    input: NewRecipeInput,
  ): RecipeVersion => ({
    userId: recipe.userId,
    recipeId: recipe.id,
    number: FIRST_VERSION,
    createdAt: recipe.createdAt,
    origin,
    // No `change`/`basedOn`: v1 is the original, it iterates on nothing and
    // changes nothing. No outcome either — it awaits its first cook.
    content: input.content,
  })
}
