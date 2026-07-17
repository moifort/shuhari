import { readyToPromote } from '~/domain/recipe/business-rules'
import { RecipeQuery } from '~/domain/recipe/query'
import type { RecipeId, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { TrialCommand } from '~/domain/trial/command'
import type { Note, Remarks, Trial } from '~/domain/trial/types'

export type RecordTrialResult = { trial: Trial; promotionSuggested: boolean }

export namespace TrialUseCase {
  // Record a trial against a version. The promotion suggestion is computed from
  // the recipe's pending pointer — no AI, so this stays instant.
  export const record = async (
    userId: UserId,
    input: {
      recipeId: RecipeId
      versionNumber: VersionNumber
      note: Note
      remarks: Remarks
      photoPath?: string | null
    },
  ) => {
    const recipe = await RecipeQuery.byId(userId, input.recipeId)
    if (recipe === 'not-found') return 'not-found'

    const trial = await TrialCommand.record(userId, {
      recipeId: input.recipeId,
      versionNumber: input.versionNumber,
      note: input.note,
      remarks: input.remarks,
      photoPath: input.photoPath ?? null,
    })
    return {
      trial,
      promotionSuggested: readyToPromote(input.note, input.versionNumber, recipe.toTest),
    }
  }
}
