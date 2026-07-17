import type { RecipeId, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import * as repository from '~/domain/trial/infrastructure/repository'
import { randomTrialId } from '~/domain/trial/primitives'
import type { Note, Remarks, Trial } from '~/domain/trial/types'
import { bulkSave } from '~/utils/firestore'

export type RecordTrialInput = {
  recipeId: RecipeId
  versionNumber: VersionNumber
  note: Note
  remarks: Remarks
  photoPath?: string | null
}

export namespace TrialCommand {
  // Record one execution: its note, remarks and optional photo.
  export const record = async (userId: UserId, input: RecordTrialInput) => {
    const trial: Trial = {
      id: randomTrialId(),
      userId,
      recipeId: input.recipeId,
      versionNumber: input.versionNumber,
      executedAt: new Date(),
      note: input.note,
      remarks: input.remarks,
      photoPath: input.photoPath ?? null,
    }
    return repository.save(trial)
  }

  export const removeByRecipe = async (userId: UserId, recipeId: RecipeId) =>
    repository.removeByRecipe(userId, recipeId)

  export const replaceAllForUser = async (userId: UserId, trials: Trial[]) => {
    await repository.removeAllByUser(userId)
    await bulkSave(trials, repository.save)
  }
}
