import type { Brand } from 'ts-brand'
import type { RecipeId, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'

export type TrialId = Brand<string, 'TrialId'>
export type Note = Brand<number, 'Note'> // integer 1..5
export type Remarks = Brand<string, 'Remarks'>

// One execution of a recipe version: its rating, free-form remarks and an
// optional result photo.
export type Trial = {
  id: TrialId
  userId: UserId
  recipeId: RecipeId
  versionNumber: VersionNumber
  executedAt: Date
  note: Note
  remarks: Remarks
  photoPath: string | null // GCS object path; never exposed raw (see photoUrl)
}
