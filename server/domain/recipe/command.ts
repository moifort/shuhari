import { alignedTmxSteps, nextVersionNumber } from '~/domain/recipe/business-rules'
import * as repository from '~/domain/recipe/infrastructure/repository'
import { randomRecipeId, VersionNumber } from '~/domain/recipe/primitives'
import type {
  DishCategory,
  Ingredient,
  Recipe,
  RecipeId,
  RecipeSubtitle,
  RecipeTitle,
  RecipeType,
  RecipeVersion,
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
  why?: string
  steps: StepText[]
  ingredients: Ingredient[]
  tmxSteps: (TmxSettings | null)[]
}

export namespace RecipeCommand {
  // Import → recipe + its v1, written atomically. v1 is the current reference and
  // is directly executable; nothing is "to test" until an iteration is proposed.
  export const importRecipe = async (
    userId: UserId,
    input: NewRecipeInput,
    sourceLabel?: string,
  ) => {
    const now = new Date()
    const recipe: Recipe = {
      id: randomRecipeId(),
      userId,
      type: input.type,
      category: input.category,
      title: input.title,
      ...(input.subtitle ? { subtitle: input.subtitle } : {}),
      currentVersion: FIRST_VERSION,
      toTest: null,
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

  // Accepted AI iteration → append version n+1 and mark it "to test". The current
  // reference is untouched until a high-scoring trial promotes the new version.
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
      ...(input.why ? { why: input.why } : {}),
      steps: input.steps,
      ingredients: input.ingredients,
      tmxSteps,
    }
    const updated: Recipe = {
      ...recipe,
      toTest: number,
      versionCount: number,
      updatedAt: new Date(),
    }
    return atomically(async (batch) => {
      await repository.saveVersion(version, batch)
      await repository.save(updated, batch)
      return updated
    })
  }

  // A high-scoring trial promotes the pending version to the new reference.
  export const promote = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumberT,
  ) => {
    const recipe = await repository.findBy(userId, recipeId)
    if (!recipe) return 'not-found' as const
    if (recipe.toTest !== versionNumber) return 'nothing-to-test' as const
    const updated: Recipe = {
      ...recipe,
      currentVersion: versionNumber,
      toTest: null,
      updatedAt: new Date(),
    }
    return repository.save(updated)
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
      steps: input.steps,
      ingredients: input.ingredients,
      tmxSteps,
    }
  }
}
