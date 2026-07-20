import { expect, test } from 'bun:test'
import { resetFakeFirestore } from '~/test/fake-firestore'

const { migration0001 } = await import('./0001-rename-version-count')

test('moves the allocator to its new name, value untouched', async () => {
  const fake = resetFakeFirestore()
  fake.seed('recipes', 'r1', { id: 'r1', title: 'Pomelo', versionCount: 3 })

  const result = await migration0001.migrate({ db: fake.db })

  expect(result).toEqual({ ok: true, transformed: 1 })
  expect(fake.snapshot('recipes').get('r1')).toEqual({
    id: 'r1',
    title: 'Pomelo',
    lastVersionNumber: 3,
  })
})

test('leaves a recipe written after the rename alone', async () => {
  const fake = resetFakeFirestore()
  fake.seed('recipes', 'r1', { id: 'r1', title: 'Pomelo', lastVersionNumber: 2 })

  const result = await migration0001.migrate({ db: fake.db })

  expect(result).toEqual({ ok: true, transformed: 0 })
  expect(fake.snapshot('recipes').get('r1')).toEqual({
    id: 'r1',
    title: 'Pomelo',
    lastVersionNumber: 2,
  })
})
