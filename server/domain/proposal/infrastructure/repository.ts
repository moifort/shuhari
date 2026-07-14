import type { Proposal } from '~/domain/proposal/types'
import type { RecipeId, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { deleteInBatches, genericDataConverter } from '~/utils/firestore'

const proposals = () => db().collection('proposals').withConverter(genericDataConverter<Proposal>())

const docId = (recipeId: RecipeId, versionNumber: VersionNumber) => `${recipeId}_${versionNumber}`

export const findBy = async (recipeId: RecipeId, versionNumber: VersionNumber) => {
  const doc = await proposals().doc(docId(recipeId, versionNumber)).get()
  return doc.data() ?? null
}

// Batch-load the active proposal for a set of (recipe, version) refs — one getAll.
export const findByRefs = async (refs: { recipeId: RecipeId; versionNumber: VersionNumber }[]) => {
  if (refs.length === 0) return []
  const docs = refs.map(({ recipeId, versionNumber }) =>
    proposals().doc(docId(recipeId, versionNumber)),
  )
  const snaps = await db().getAll(...docs)
  return snaps.map((snap) => snap.data()).filter((p): p is Proposal => p !== undefined)
}

export const save = async (proposal: Proposal) => {
  await proposals().doc(docId(proposal.recipeId, proposal.versionNumber)).set(proposal)
  return proposal
}

export const remove = async (recipeId: RecipeId, versionNumber: VersionNumber) => {
  await proposals().doc(docId(recipeId, versionNumber)).delete()
}

export const removeByRecipe = async (userId: UserId, recipeId: RecipeId) => {
  const snap = await proposals()
    .where('userId', '==', userId)
    .where('recipeId', '==', recipeId)
    .get()
  await deleteInBatches(snap.docs.map((doc) => doc.ref))
}

export const removeAllByUser = async (userId: UserId) => {
  const snap = await proposals().where('userId', '==', userId).get()
  await deleteInBatches(snap.docs.map((doc) => doc.ref))
}
