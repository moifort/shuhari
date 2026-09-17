import { expect, test } from 'bun:test'
import { resetFakeFirestore } from '~/test/fake-firestore'

const { migration0011 } = await import('./0011-thermomix-tag-onto-the-recipe')

type Fake = ReturnType<typeof resetFakeFirestore>

const seedRecipe = (fake: Fake, id: string, fields: Record<string, unknown>) =>
  fake.seed('recipes', id, { id, userId: 'user-1', title: 'Risotto', ...fields })

test('tags every Thermomix recipe stored before tags existed', async () => {
  const fake = resetFakeFirestore()
  seedRecipe(fake, 'r1', { type: 'thermomix' })

  const result = await migration0011.migrate({ db: fake.db })

  expect(result).toEqual({ ok: true, transformed: 1 })
  expect(fake.snapshot('recipes').get('r1')).toEqual({
    id: 'r1',
    userId: 'user-1',
    title: 'Risotto',
    type: 'thermomix',
    tags: [{ label: 'Thermomix', icon: 'thermomix' }],
  })
})

test('a dish and a coffee are filed under nothing', async () => {
  const fake = resetFakeFirestore()
  seedRecipe(fake, 'dish', { type: 'dish' })
  seedRecipe(fake, 'coffee', { type: 'coffee' })

  const result = await migration0011.migrate({ db: fake.db })

  expect(result).toEqual({ ok: true, transformed: 0 })
  expect(fake.snapshot('recipes').get('dish')?.tags).toBeUndefined()
  expect(fake.snapshot('recipes').get('coffee')?.tags).toBeUndefined()
})

test('leaves alone a recipe the cook already tagged', async () => {
  const fake = resetFakeFirestore()
  seedRecipe(fake, 'r1', { type: 'thermomix', tags: [{ label: 'Noël' }] })

  const result = await migration0011.migrate({ db: fake.db })

  expect(result).toEqual({ ok: true, transformed: 0 })
  expect(fake.snapshot('recipes').get('r1')?.tags).toEqual([{ label: 'Noël' }])
})
