import * as repository from '~/domain/proposal/infrastructure/repository'
import type { RecipeId, VersionNumber } from '~/domain/recipe/types'

export namespace ProposalQuery {
  export const byRef = async (recipeId: RecipeId, versionNumber: VersionNumber) =>
    repository.findBy(recipeId, versionNumber)

  export const byRefs = async (refs: { recipeId: RecipeId; versionNumber: VersionNumber }[]) =>
    repository.findByRefs(refs)
}
