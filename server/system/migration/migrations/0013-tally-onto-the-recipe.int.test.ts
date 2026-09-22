import { expect, test } from 'bun:test'
import { resetFakeFirestore } from '~/test/fake-firestore'

const { migration0013 } = await import('./0013-tally-onto-the-recipe')

test('stamps the best rating, the version count and the versions owing a try', async () => {
  const fake = resetFakeFirestore()
  fake.seed('recipes', 'r1', { id: 'r1', title: 'Crumble aux pommes' })
  fake.seed('recipe-versions', 'r1_1', { recipeId: 'r1', number: 1, rating: 3 })
  fake.seed('recipe-versions', 'r1_2', { recipeId: 'r1', number: 2, rating: 5 })
  fake.seed('recipe-versions', 'r1_3', { recipeId: 'r1', number: 3, toTest: true })

  const result = await migration0013.migrate({ db: fake.db })

  expect(result).toEqual({ ok: true, transformed: 1 })
  expect(fake.snapshot('recipes').get('r1')).toEqual({
    id: 'r1',
    title: 'Crumble aux pommes',
    bestRating: 5,
    versionCount: 3,
    toTestCount: 1,
  })
})

test('a recipe never cooked carries no best rating', async () => {
  const fake = resetFakeFirestore()
  fake.seed('recipes', 'r2', { id: 'r2', bestRating: 4 })
  fake.seed('recipe-versions', 'r2_1', { recipeId: 'r2', number: 1 })

  await migration0013.migrate({ db: fake.db })

  expect(fake.snapshot('recipes').get('r2')).toEqual({ id: 'r2', versionCount: 1, toTestCount: 0 })
})

test('leaves a recipe that already carries its tally untouched', async () => {
  const fake = resetFakeFirestore()
  fake.seed('recipes', 'r3', { id: 'r3', bestRating: 4, versionCount: 1, toTestCount: 0 })
  fake.seed('recipe-versions', 'r3_1', { recipeId: 'r3', number: 1, rating: 4 })

  const result = await migration0013.migrate({ db: fake.db })

  expect(result).toEqual({ ok: true, transformed: 0 })
})
