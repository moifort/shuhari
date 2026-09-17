import { expect, test } from 'bun:test'
import { resetFakeFirestore } from '~/test/fake-firestore'

const { migration0010 } = await import('./0010-standing-onto-the-recipe')

test('a hearted recipe stands above any rating', async () => {
  const fake = resetFakeFirestore()
  fake.seed('recipes', 'r1', { id: 'r1', title: 'Crumble aux pommes', favorite: true })
  fake.seed('recipe-versions', 'r1_1', { recipeId: 'r1', number: 1, rating: 5 })
  fake.seed('recipe-versions', 'r1_2', { recipeId: 'r1', number: 2, rating: 3, favorite: true })

  const result = await migration0010.migrate({ db: fake.db })

  expect(result).toEqual({ ok: true, transformed: 1 })
  expect(fake.snapshot('recipes').get('r1')).toEqual({
    id: 'r1',
    title: 'Crumble aux pommes',
    favorite: true,
    standing: 10,
  })
})

test('a recipe without a heart stands at its best rating', async () => {
  const fake = resetFakeFirestore()
  fake.seed('recipes', 'r2', { id: 'r2' })
  fake.seed('recipe-versions', 'r2_1', { recipeId: 'r2', number: 1, rating: 4 })
  fake.seed('recipe-versions', 'r2_2', { recipeId: 'r2', number: 2, rating: 2 })
  fake.seed('recipe-versions', 'r2_3', { recipeId: 'r2', number: 3 })

  await migration0010.migrate({ db: fake.db })

  expect(fake.snapshot('recipes').get('r2')?.standing).toBe(4)
})

test('a recipe never cooked — or seen without its lineage — stands last, not nowhere', async () => {
  const fake = resetFakeFirestore()
  fake.seed('recipes', 'r3', { id: 'r3' })
  fake.seed('recipe-versions', 'r3_1', { recipeId: 'r3', number: 1 })
  fake.seed('recipes', 'r4', { id: 'r4' })

  await migration0010.migrate({ db: fake.db })

  expect(fake.snapshot('recipes').get('r3')?.standing).toBe(0)
  expect(fake.snapshot('recipes').get('r4')?.standing).toBe(0)
})

test('leaves a recipe that already carries its standing untouched', async () => {
  const fake = resetFakeFirestore()
  fake.seed('recipes', 'r5', { id: 'r5', standing: 3 })
  fake.seed('recipe-versions', 'r5_1', { recipeId: 'r5', number: 1, rating: 3 })

  const result = await migration0010.migrate({ db: fake.db })

  expect(result).toEqual({ ok: true, transformed: 0 })
})
