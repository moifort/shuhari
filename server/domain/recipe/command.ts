import { alignedTmxSteps, nextVersionNumber } from '~/domain/recipe/business-rules'
import * as repository from '~/domain/recipe/infrastructure/repository'
import { randomRecipeId, VersionNumber } from '~/domain/recipe/primitives'
import type {
  DishCategory,
  Ingredient,
  Note,
  Recipe,
  RecipeId,
  RecipeSubtitle,
  RecipeTitle,
  RecipeType,
  RecipeVersion,
  Remarks,
  StepText,
  TmxSettings,
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
  subtitle?: RecipeSubtitle
  steps: StepText[]
  ingredients: Ingredient[]
  tmxSteps: (TmxSettings | null)[]
}

export type NewVersionInput = {
  change: string
  basedOn: VersionNumberT | null
  why?: string
  steps: StepText[]
  ingredients: Ingredient[]
  tmxSteps: (TmxSettings | null)[]
}

export type RecordEssaiInput = {
  recipeId: RecipeId
  versionNumber: VersionNumberT
  note: Note
  remarks: Remarks
  photoPath?: string | null
}

export namespace RecipeCommand {
  // Create → recipe + its v1, written atomically. v1 is the original "essai à faire"
  // (`basedOn` is null, it iterates on nothing) and awaits its first cook.
  export const create = async (userId: UserId, input: NewRecipeInput, sourceLabel?: string) => {
    const now = new Date()
    const recipe: Recipe = {
      id: randomRecipeId(),
      userId,
      type: input.type,
      category: input.category,
      title: input.title,
      ...(input.subtitle ? { subtitle: input.subtitle } : {}),
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
  // recipe just bumps its `versionCount` and `updatedAt`.
  export const addVersion = async (userId: UserId, recipeId: RecipeId, input: NewVersionInput) => {
    const recipe = await repository.findBy(userId, recipeId)
    if (!recipe) return 'not-found' as const
    const number = nextVersionNumber(recipe.versionCount)
    const tmxSteps = recipe.type === 'tmx' ? alignedTmxSteps(input.steps, input.tmxSteps) : []
    const version: RecipeVersion = {
      userId,
      recipeId,
      number,
      createdAt: new Date(),
      origin: { kind: 'ai-proposal' },
      change: input.change,
      basedOn: input.basedOn,
      ...(input.why ? { why: input.why } : {}),
      steps: input.steps,
      ingredients: input.ingredients,
      tmxSteps,
      executedAt: null,
      note: null,
      remarks: null,
      photoPath: null,
    }
    const updated: Recipe = {
      ...recipe,
      versionCount: number,
      updatedAt: new Date(),
    }
    return atomically(async (batch) => {
      await repository.saveVersion(version, batch)
      await repository.save(updated, batch)
      return updated
    })
  }

  // Record the essai outcome onto a version — overwritable: re-cooking the same
  // version simply rewrites its note/remarks/executedAt in place. The outcome and
  // the recipe's `updatedAt` bump land in one batch (all-or-nothing).
  export const recordEssai = async (
    userId: UserId,
    input: RecordEssaiInput,
  ): Promise<RecipeVersion | 'not-found'> => {
    const recipe = await repository.findBy(userId, input.recipeId)
    if (!recipe) return 'not-found' as const
    const version = await repository.findVersion(input.recipeId, input.versionNumber)
    if (!version) return 'not-found' as const
    const executed: RecipeVersion = {
      ...version,
      executedAt: new Date(),
      note: input.note,
      remarks: input.remarks,
      photoPath: input.photoPath ?? null,
    }
    const updatedRecipe: Recipe = { ...recipe, updatedAt: new Date() }
    return atomically(async (batch) => {
      await repository.saveVersion(executed, batch)
      await repository.save(updatedRecipe, batch)
      return executed
    })
  }

  export const rename = async (
    userId: UserId,
    recipeId: RecipeId,
    fields: { title?: RecipeTitle; subtitle?: RecipeSubtitle },
  ) => {
    const recipe = await repository.findBy(userId, recipeId)
    if (!recipe) return 'not-found' as const
    const updated: Recipe = {
      ...recipe,
      ...(fields.title ? { title: fields.title } : {}),
      ...(fields.subtitle ? { subtitle: fields.subtitle } : {}),
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

  const firstVersion = (recipe: Recipe, origin: VersionOrigin, input: NewRecipeInput) => {
    // Thermomix settings only exist on tmx recipes — [] for any other type.
    const tmxSteps = recipe.type === 'tmx' ? alignedTmxSteps(input.steps, input.tmxSteps) : []
    return {
      userId: recipe.userId,
      recipeId: recipe.id,
      number: FIRST_VERSION,
      createdAt: recipe.createdAt,
      origin,
      change: null,
      basedOn: null,
      steps: input.steps,
      ingredients: input.ingredients,
      tmxSteps,
      executedAt: null,
      note: null,
      remarks: null,
      photoPath: null,
    }
  }
}
