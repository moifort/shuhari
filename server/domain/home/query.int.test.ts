import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { Note, RecipeTitle, Remarks, StepText, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { RecipeCommand } = await import('~/domain/recipe/command')
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
  test('partitions recipes into to-test vs library and lists recent essais', async () => {
    const a = await RecipeCommand.importRecipe(userId, input('Blanquette'))
    await RecipeCommand.importRecipe(userId, input('Ratatouille'))
    // Record v1's essai on recipe A and promote it, so it leaves "to test" and
    // shows up as a recent essai — B stays pending (fresh import).
    await RecipeCommand.recordEssai(userId, {
      recipeId: a.id,
      versionNumber: 1 as VersionNumber,
      note: 5 as Note,
      remarks: 'Trop salé' as Remarks,
    })
    await RecipeCommand.promote(userId, a.id, 1 as VersionNumber)

    const home = await HomeQuery.load(userId)

    expect(home.library.length).toBe(2)
    expect(home.toTest.map((r) => r.title as string)).toEqual(['Ratatouille'])
    expect(home.recentEssais.length).toBe(1)
    expect(home.recentEssais[0].note).toBe(5 as Note)
  })

  test('costs two collection scans and memoizes repeated recipe reads', async () => {
    await RecipeCommand.importRecipe(userId, input('Blanquette'))

    const before = fake.queryReads
    await HomeQuery.load(userId)
    // One recipes scan + one recipe-versions scan.
    expect(fake.queryReads - before).toBe(2)

    // Both scans are memoized per request: re-reading recipes or the full version
    // lineage (as the bestNote loader does) in the same request adds no scan.
    const afterLoad = fake.queryReads
    await RecipeQuery.all(userId)
    await RecipeQuery.allVersions(userId)
    expect(fake.queryReads - afterLoad).toBe(0)
  })
})
