import type { Brand } from 'ts-brand'
import type { Param, RecipeId, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'

export type TrialId = Brand<string, 'TrialId'>
export type Note = Brand<number, 'Note'> // integer 1..5
export type Remarks = Brand<string, 'Remarks'>

// One execution of a recipe version. `realParams` holds ONLY the parameters that
// actually deviated from the version's target — the pillar of reproducibility
// ("refaire exactement cet essai" replays target params overlaid with these).
export type Trial = {
  id: TrialId
  userId: UserId
  recipeId: RecipeId
  versionNumber: VersionNumber
  executedAt: Date
  note: Note
  remarks: Remarks
  realParams: Param[]
  photoPath: string | null // GCS object path; never exposed raw (see photoUrl)
}
