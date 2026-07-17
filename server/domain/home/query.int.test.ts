import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { RecipeTitle, StepText } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import type { Note, Remarks } from '~/domain/trial/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { RecipeCommand } = await import('~/domain/recipe/command')
const { TrialCommand } = await import('~/domain/trial/command')
const { HomeQuery } = await import('~/domain/home/query')
const { RecipeQuery } = await import('~/domain/recipe/query')

const userId = 'user-1' as UserId
const input = (title: string) => ({
  type: 'plat' as const,
  category: 'plat' as const,
  title: title as RecipeTitle,
  steps: ['Mijoter'] as StepText[],
  ingredients: [],
  tmxSteps: [],
})

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('HomeQuery.load', () => {
  test('partitions recipes into to-test vs library and lists recent trials', async () => {
    const a = await RecipeCommand.importRecipe(userId, input('Blanquette'))
    await RecipeCommand.importRecipe(userId, input('Ratatouille'))
    // Give recipe A a pending version so it shows under "to test".
    await RecipeCommand.addVersion(userId, a.id, {
      change: 'Bouillon 700 → 650 ml',
      steps: ['Mijoter'] as StepText[],
      ingredients: [],
      tmxSteps: [],
    })
    await TrialCommand.record(userId, {
      recipeId: a.id,
      versionNumber: a.currentVersion,
      note: 5 as Note,
      remarks: 'Trop salé' as Remarks,
    })

    const home = await HomeQuery.load(userId)

    expect(home.library.length).toBe(2)
    expect(home.toTest.map((r) => r.id)).toEqual([a.id])
    expect(home.recentTrials.length).toBe(1)
    expect(home.recentTrials[0].note).toBe(5 as Note)
  })

  test('costs two collection scans and memoizes repeated recipe reads', async () => {
    await RecipeCommand.importRecipe(userId, input('Blanquette'))

    const before = fake.queryReads
    await HomeQuery.load(userId)
    // One recipes scan + one trials scan.
    expect(fake.queryReads - before).toBe(2)

    // A second recipes read in the same request is served from the request cache.
    const afterLoad = fake.queryReads
    await RecipeQuery.all(userId)
    expect(fake.queryReads - afterLoad).toBe(0)
  })
})
