import * as repository from '~/domain/proposal/infrastructure/repository'
import type { Proposal } from '~/domain/proposal/types'
import type { RecipeId, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'

export namespace ProposalCommand {
  export const propose = async (proposal: Proposal) => repository.save(proposal)

  // Accepting or refusing a proposal removes it (presence == pending).
  export const discard = async (recipeId: RecipeId, versionNumber: VersionNumber) =>
    repository.remove(recipeId, versionNumber)

  export const removeByRecipe = async (userId: UserId, recipeId: RecipeId) =>
    repository.removeByRecipe(userId, recipeId)
}
