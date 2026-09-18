import { expect, test } from 'bun:test'
import { resetFakeFirestore } from '~/test/fake-firestore'

const { migration0012 } = await import('./0012-mise-en-place-onto-the-version')

type Fake = ReturnType<typeof resetFakeFirestore>

const seedVersion = (fake: Fake, id: string, content: Record<string, unknown>) =>
  fake.seed('recipe-versions', id, { recipeId: 'r1', number: 1, content })

test('gives every cooked version stored before the section an empty mise en place', async () => {
  const fake = resetFakeFirestore()
  seedVersion(fake, 'dish_1', { kind: 'dish', ingredients: [], steps: ['Enfourner'] })
  seedVersion(fake, 'tm_1', {
    kind: 'thermomix',
    ingredients: [],
    steps: [{ text: 'Mixer', settings: {} }],
  })

  const result = await migration0012.migrate({ db: fake.db })

  expect(result).toEqual({ ok: true, transformed: 2 })
  expect(fake.snapshot('recipe-versions').get('dish_1')?.content).toEqual({
    kind: 'dish',
    ingredients: [],
    miseEnPlace: [],
    steps: ['Enfourner'],
  })
  expect(fake.snapshot('recipe-versions').get('tm_1')?.content).toEqual({
    kind: 'thermomix',
    ingredients: [],
    miseEnPlace: [],
    steps: [{ text: 'Mixer', settings: {} }],
  })
})

test('leaves a coffee alone — it readies nothing', async () => {
  const fake = resetFakeFirestore()
  seedVersion(fake, 'coffee_1', { kind: 'coffee', beans: {}, water: {}, extraction: {}, gear: {} })

  const result = await migration0012.migrate({ db: fake.db })

  expect(result).toEqual({ ok: true, transformed: 0 })
  expect(fake.snapshot('recipe-versions').get('coffee_1')?.content).toEqual({
    kind: 'coffee',
    beans: {},
    water: {},
    extraction: {},
    gear: {},
  })
})

test('leaves alone a version the AI already wrote a mise en place on', async () => {
  const fake = resetFakeFirestore()
  seedVersion(fake, 'dish_1', {
    kind: 'dish',
    ingredients: [],
    miseEnPlace: ['Préchauffer le four à 180 °C'],
    steps: ['Enfourner'],
  })

  const result = await migration0012.migrate({ db: fake.db })

  expect(result).toEqual({ ok: true, transformed: 0 })
  expect(fake.snapshot('recipe-versions').get('dish_1')?.content).toEqual({
    kind: 'dish',
    ingredients: [],
    miseEnPlace: ['Préchauffer le four à 180 °C'],
    steps: ['Enfourner'],
  })
})
