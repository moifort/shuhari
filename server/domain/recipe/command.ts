import { nextVersionNumber } from '~/domain/recipe/business-rules'
import * as repository from '~/domain/recipe/infrastructure/repository'
import { randomRecipeId, VersionNumber } from '~/domain/recipe/primitives'
import type {
  Param,
  Recipe,
  RecipeId,
  RecipeSubtitle,
  RecipeTitle,
  RecipeType,
  RecipeVersion,
  StepText,
  VersionNumber as VersionNumberT,
  VersionOrigin,
} from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { atomically, bulkSave } from '~/utils/firestore'

const FIRST_VERSION = VersionNumber(1)

export type NewRecipeInput = {
  type: RecipeType
  title: RecipeTitle
  subtitle?: RecipeSubtitle
  params: Param[]
  steps: StepText[]
}

export type NewVersionInput = {
  change: string
  changedKeys: RecipeVersion['changedKeys']
  why?: string
  params: Param[]
  steps: StepText[]
}

export namespace RecipeCommand {
  // Import → recipe + its v1, written atomically. v1 is the current reference and
  // is directly executable; nothing is "to test" until an iteration is proposed.
  export const importRecipe = async (
    userId: UserId,
    input: NewRecipeInput,
    sourceLabel?: string,
  ): Promise<Recipe> => {
    const now = new Date()
    const recipe: Recipe = {
      id: randomRecipeId(),
      userId,
      type: input.type,
      title: input.title,
      ...(input.subtitle ? { subtitle: input.subtitle } : {}),
      currentVersion: FIRST_VERSION,
      toTest: null,
      versionCount: FIRST_VERSION,
      derivedFrom: null,
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
  export const addVersion = async (
    userId: UserId,
    recipeId: RecipeId,
    input: NewVersionInput,
  ): Promise<Recipe | 'not-found'> => {
    const recipe = await repository.findBy(userId, recipeId)
    if (!recipe) return 'not-found' as const
    const number = nextVersionNumber(recipe.versionCount)
    const version: RecipeVersion = {
      userId,
      recipeId,
      number,
      createdAt: new Date(),
      origin: { kind: 'ai-proposal' },
      change: input.change,
      changedKeys: input.changedKeys,
      ...(input.why ? { why: input.why } : {}),
      params: input.params,
      steps: input.steps,
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
  ): Promise<Recipe | 'not-found' | 'nothing-to-test'> => {
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

  // Accepted AI variation → a brand-new recipe linked to its parent, with its own
  // fresh v1 lineage.
  export const deriveVariation = async (
    userId: UserId,
    parentId: RecipeId,
    input: NewRecipeInput,
    change: string,
  ): Promise<Recipe | 'not-found'> => {
    const parent = await repository.findBy(userId, parentId)
    if (!parent) return 'not-found' as const
    const now = new Date()
    const recipe: Recipe = {
      id: randomRecipeId(),
      userId,
      type: input.type,
      title: input.title,
      ...(input.subtitle ? { subtitle: input.subtitle } : {}),
      currentVersion: FIRST_VERSION,
      toTest: null,
      versionCount: FIRST_VERSION,
      derivedFrom: parentId,
      createdAt: now,
      updatedAt: now,
    }
    const origin: VersionOrigin = { kind: 'ai-proposal', detail: change }
    return atomically(async (batch) => {
      await repository.save(recipe, batch)
      await repository.saveVersion(firstVersion(recipe, origin, input), batch)
      return recipe
    })
  }

  export const rename = async (
    userId: UserId,
    recipeId: RecipeId,
    fields: { title?: RecipeTitle; subtitle?: RecipeSubtitle },
  ): Promise<Recipe | 'not-found'> => {
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

  export const remove = async (
    userId: UserId,
    recipeId: RecipeId,
  ): Promise<undefined | 'not-found'> => {
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
  ): Promise<void> => {
    await repository.removeAllByUser(userId)
    await bulkSave(recipes, (recipe) => repository.save(recipe))
    await bulkSave(versions, (version) => repository.saveVersion(version))
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
    change: null,
    changedKeys: [],
    params: input.params,
    steps: input.steps,
  })
}
