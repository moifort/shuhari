import type { Param, RecipeId, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { realDeviations } from '~/domain/trial/business-rules'
import * as repository from '~/domain/trial/infrastructure/repository'
import { randomTrialId } from '~/domain/trial/primitives'
import type { Note, Remarks, Trial } from '~/domain/trial/types'
import { bulkSave } from '~/utils/firestore'

export type RecordTrialInput = {
  recipeId: RecipeId
  versionNumber: VersionNumber
  note: Note
  remarks: Remarks
  targetParams: Param[]
  enteredParams: Param[]
  photoPath?: string | null
}

export namespace TrialCommand {
  // Record one execution. Only the parameters that deviated from the version's
  // targets are stored (`realParams`) — the reproducibility delta.
  export const record = async (userId: UserId, input: RecordTrialInput): Promise<Trial> => {
    const trial: Trial = {
      id: randomTrialId(),
      userId,
      recipeId: input.recipeId,
      versionNumber: input.versionNumber,
      executedAt: new Date(),
      note: input.note,
      remarks: input.remarks,
      realParams: realDeviations(input.targetParams, input.enteredParams),
      photoPath: input.photoPath ?? null,
    }
    return repository.save(trial)
  }

  export const removeByRecipe = async (userId: UserId, recipeId: RecipeId): Promise<void> =>
    repository.removeByRecipe(userId, recipeId)

  export const replaceAllForUser = async (userId: UserId, trials: Trial[]): Promise<void> => {
    await repository.removeAllByUser(userId)
    await bulkSave(trials, repository.save)
  }
}
