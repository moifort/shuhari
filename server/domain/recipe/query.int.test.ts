import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { DishCategory, RecipeId, RecipeType } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { RecipeQuery } = await import('~/domain/recipe/query')
const { categoryRank } = await import('~/domain/recipe/business-rules')

const userId = 'user-1' as UserId

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
})

// Seed a raw recipe doc — only the fields the paginated library reads (owner,
// facet, sort keys). categoryRank mirrors what the repository stamps on save.
const seedRecipe = (
  id: string,
  fields: { type?: RecipeType; category: DishCategory; updatedAt: number; owner?: UserId },
) => {
  fake.seed('recipes', id, {
    id,
    userId: fields.owner ?? userId,
    type: fields.type ?? 'plat',
    category: fields.category,
    categoryRank: categoryRank(fields.category),
    updatedAt: new Date(fields.updatedAt),
  })
}

const ids = (page: { items: { id: RecipeId }[] }) => page.items.map((r) => String(r.id))

describe('RecipeQuery.library — updatedAt sort & cursor pagination', () => {
  beforeEach(() => {
    seedRecipe('r1', { category: 'plat', updatedAt: 1000 })
    seedRecipe('r2', { category: 'plat', updatedAt: 2000 })
    seedRecipe('r3', { category: 'plat', updatedAt: 3000 })
  })

  test('orders by updatedAt desc and reports hasMore on a full page', async () => {
    const page = await RecipeQuery.library(userId, {
      sort: 'updatedAt',
      order: 'desc',
      limit: 2,
    })
    expect(ids(page)).toEqual(['r3', 'r2'])
    expect(page.hasMore).toBe(true)
    expect(page.totalCount).toBe(2)
  })

  test('the cursor returns the following page and clears hasMore at the end', async () => {
    const page2 = await RecipeQuery.library(userId, {
      sort: 'updatedAt',
      order: 'desc',
      limit: 2,
      after: 'r2' as RecipeId,
    })
    expect(ids(page2)).toEqual(['r1'])
    expect(page2.hasMore).toBe(false)
    expect(page2.totalCount).toBe(1)
  })

  test('breaks equal-updatedAt ties by id in the sort direction (desc)', async () => {
    // Same updatedAt across all three: the implicit id tie-break must follow the
    // last orderBy direction (desc), so ids come back descending, not ascending.
    seedRecipe('a', { category: 'plat', updatedAt: 5000 })
    seedRecipe('b', { category: 'plat', updatedAt: 5000 })
    seedRecipe('c', { category: 'plat', updatedAt: 5000 })
    const page = await RecipeQuery.library(userId, { sort: 'updatedAt', order: 'desc', limit: 3 })
    expect(ids(page)).toEqual(['c', 'b', 'a'])
  })

  test('honours ascending order', async () => {
    const page = await RecipeQuery.library(userId, { sort: 'updatedAt', order: 'asc', limit: 10 })
    expect(ids(page)).toEqual(['r1', 'r2', 'r3'])
    expect(page.hasMore).toBe(false)
  })

  test('excludes other users’ recipes', async () => {
    seedRecipe('foreign', { category: 'plat', updatedAt: 9000, owner: 'user-2' as UserId })
    const page = await RecipeQuery.library(userId, { sort: 'updatedAt', order: 'desc', limit: 10 })
    expect(ids(page)).toEqual(['r3', 'r2', 'r1'])
  })
})

describe('RecipeQuery.library — category business order', () => {
  test('sorts by course order (entrée → … → boulangerie), not alphabetically', async () => {
    // Seeded in a deliberately scrambled, non-alphabetical order.
    seedRecipe('boul', { category: 'boulangerie', updatedAt: 1000 })
    seedRecipe('entr', { category: 'entree', updatedAt: 1000 })
    seedRecipe('dess', { category: 'dessert', updatedAt: 1000 })
    seedRecipe('sauc', { category: 'sauce', updatedAt: 1000 })

    const page = await RecipeQuery.library(userId, { sort: 'category', order: 'desc', limit: 10 })
    // entree(0) < dessert(2) < sauce(4) < boulangerie(5) — 'boul' is NOT first
    // despite being alphabetically before the others.
    expect(ids(page)).toEqual(['entr', 'dess', 'sauc', 'boul'])
  })

  test('breaks category ties by updatedAt desc', async () => {
    seedRecipe('old', { category: 'plat', updatedAt: 1000 })
    seedRecipe('new', { category: 'plat', updatedAt: 3000 })
    seedRecipe('mid', { category: 'plat', updatedAt: 2000 })

    const page = await RecipeQuery.library(userId, { sort: 'category', order: 'desc', limit: 10 })
    expect(ids(page)).toEqual(['new', 'mid', 'old'])
  })
})

describe('RecipeQuery.library — type filter', () => {
  beforeEach(() => {
    seedRecipe('plat-a', { type: 'plat', category: 'plat', updatedAt: 1000 })
    seedRecipe('tmx-a', { type: 'tmx', category: 'dessert', updatedAt: 2000 })
    seedRecipe('tmx-b', { type: 'tmx', category: 'entree', updatedAt: 3000 })
  })

  test('keeps only the requested type, combined with the sort', async () => {
    const page = await RecipeQuery.library(userId, {
      type: 'tmx',
      sort: 'updatedAt',
      order: 'desc',
      limit: 10,
    })
    expect(ids(page)).toEqual(['tmx-b', 'tmx-a'])
    expect(page.hasMore).toBe(false)
  })

  test('the type filter also applies under the category sort', async () => {
    const page = await RecipeQuery.library(userId, {
      type: 'tmx',
      sort: 'category',
      order: 'desc',
      limit: 10,
    })
    // entree(0) before dessert(2)
    expect(ids(page)).toEqual(['tmx-b', 'tmx-a'])
  })
})

describe('RecipeQuery.library — limit clamp', () => {
  beforeEach(() => {
    for (let i = 0; i < 3; i++) seedRecipe(`r${i}`, { category: 'plat', updatedAt: 1000 + i })
  })

  test('clamps a non-positive limit up to 1', async () => {
    const page = await RecipeQuery.library(userId, { sort: 'updatedAt', order: 'desc', limit: 0 })
    expect(page.items.length).toBe(1)
    expect(page.hasMore).toBe(true)
  })

  test('an oversized limit still returns every matching recipe', async () => {
    const page = await RecipeQuery.library(userId, { sort: 'updatedAt', order: 'desc', limit: 999 })
    expect(page.items.length).toBe(3)
    expect(page.hasMore).toBe(false)
  })

  test('caps the page at 50 recipes whatever the requested limit', async () => {
    for (let i = 3; i < 51; i++) seedRecipe(`r${i}`, { category: 'plat', updatedAt: 1000 + i })
    const page = await RecipeQuery.library(userId, { sort: 'updatedAt', order: 'desc', limit: 999 })
    expect(page.items.length).toBe(50)
    expect(page.hasMore).toBe(true)
  })
})
