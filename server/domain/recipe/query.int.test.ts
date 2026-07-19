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
  fields: {
    type?: RecipeType
    category: DishCategory
    updatedAt: number
    owner?: UserId
    favorite?: true
  },
) => {
  fake.seed('recipes', id, {
    id,
    userId: fields.owner ?? userId,
    type: fields.type ?? 'dish',
    category: fields.category,
    categoryRank: categoryRank(fields.category),
    // Absent unless marked, exactly as the aggregate stores it.
    ...(fields.favorite ? { favorite: true } : {}),
    updatedAt: new Date(fields.updatedAt),
  })
}

const ids = (page: { items: { id: RecipeId }[] }) => page.items.map((r) => String(r.id))

describe('RecipeQuery.library — updatedAt sort & cursor pagination', () => {
  beforeEach(() => {
    seedRecipe('r1', { category: 'main', updatedAt: 1000 })
    seedRecipe('r2', { category: 'main', updatedAt: 2000 })
    seedRecipe('r3', { category: 'main', updatedAt: 3000 })
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
    seedRecipe('a', { category: 'main', updatedAt: 5000 })
    seedRecipe('b', { category: 'main', updatedAt: 5000 })
    seedRecipe('c', { category: 'main', updatedAt: 5000 })
    const page = await RecipeQuery.library(userId, { sort: 'updatedAt', order: 'desc', limit: 3 })
    expect(ids(page)).toEqual(['c', 'b', 'a'])
  })

  test('honours ascending order', async () => {
    const page = await RecipeQuery.library(userId, { sort: 'updatedAt', order: 'asc', limit: 10 })
    expect(ids(page)).toEqual(['r1', 'r2', 'r3'])
    expect(page.hasMore).toBe(false)
  })

  test('excludes other users’ recipes', async () => {
    seedRecipe('foreign', { category: 'main', updatedAt: 9000, owner: 'user-2' as UserId })
    const page = await RecipeQuery.library(userId, { sort: 'updatedAt', order: 'desc', limit: 10 })
    expect(ids(page)).toEqual(['r3', 'r2', 'r1'])
  })
})

describe('RecipeQuery.library — category business order', () => {
  test('sorts by course order (starter → … → baking), not alphabetically', async () => {
    // Seeded in a deliberately scrambled, non-alphabetical order.
    seedRecipe('boul', { category: 'baking', updatedAt: 1000 })
    seedRecipe('entr', { category: 'starter', updatedAt: 1000 })
    seedRecipe('dess', { category: 'dessert', updatedAt: 1000 })
    seedRecipe('sauc', { category: 'sauce', updatedAt: 1000 })

    const page = await RecipeQuery.library(userId, { sort: 'category', order: 'desc', limit: 10 })
    // starter(0) < dessert(2) < sauce(4) < baking(5) — 'boul' is NOT first
    // despite being alphabetically before the others.
    expect(ids(page)).toEqual(['entr', 'dess', 'sauc', 'boul'])
  })

  test('breaks category ties by updatedAt desc', async () => {
    seedRecipe('old', { category: 'main', updatedAt: 1000 })
    seedRecipe('new', { category: 'main', updatedAt: 3000 })
    seedRecipe('mid', { category: 'main', updatedAt: 2000 })

    const page = await RecipeQuery.library(userId, { sort: 'category', order: 'desc', limit: 10 })
    expect(ids(page)).toEqual(['new', 'mid', 'old'])
  })
})

describe('RecipeQuery.library — type filter', () => {
  beforeEach(() => {
    seedRecipe('dish-a', { type: 'dish', category: 'main', updatedAt: 1000 })
    seedRecipe('thermomix-a', { type: 'thermomix', category: 'dessert', updatedAt: 2000 })
    seedRecipe('thermomix-b', { type: 'thermomix', category: 'starter', updatedAt: 3000 })
  })

  test('keeps only the requested type, combined with the sort', async () => {
    const page = await RecipeQuery.library(userId, {
      type: 'thermomix',
      sort: 'updatedAt',
      order: 'desc',
      limit: 10,
    })
    expect(ids(page)).toEqual(['thermomix-b', 'thermomix-a'])
    expect(page.hasMore).toBe(false)
  })

  test('the type filter also applies under the category sort', async () => {
    const page = await RecipeQuery.library(userId, {
      type: 'thermomix',
      sort: 'category',
      order: 'desc',
      limit: 10,
    })
    // starter(0) before dessert(2)
    expect(ids(page)).toEqual(['thermomix-b', 'thermomix-a'])
  })
})

describe('RecipeQuery.library — favourites lens', () => {
  beforeEach(() => {
    seedRecipe('fav-dish', { type: 'dish', category: 'main', updatedAt: 1000, favorite: true })
    seedRecipe('plain-dish', { type: 'dish', category: 'starter', updatedAt: 2000 })
    seedRecipe('fav-thermomix', {
      type: 'thermomix',
      category: 'dessert',
      updatedAt: 3000,
      favorite: true,
    })
  })

  test('keeps only the favourites, every type mixed, in course order', async () => {
    const page = await RecipeQuery.library(userId, {
      favorite: true,
      sort: 'category',
      order: 'desc',
      limit: 10,
    })
    // main(1) before dessert(2); the un-favourited starter is out despite ranking first.
    expect(ids(page)).toEqual(['fav-dish', 'fav-thermomix'])
  })

  test('without the facet the library still returns everything', async () => {
    const page = await RecipeQuery.library(userId, { sort: 'updatedAt', order: 'desc', limit: 10 })
    expect(ids(page)).toEqual(['fav-thermomix', 'plain-dish', 'fav-dish'])
  })
})

describe('RecipeQuery.library — category filter', () => {
  beforeEach(() => {
    seedRecipe('dish-old', { type: 'dish', category: 'main', updatedAt: 1000 })
    seedRecipe('dessert-a', { type: 'dish', category: 'dessert', updatedAt: 2000 })
    seedRecipe('dish-new', { type: 'thermomix', category: 'main', updatedAt: 3000 })
    seedRecipe('dessert-b', { type: 'thermomix', category: 'dessert', updatedAt: 4000 })
  })

  test('keeps only the requested category, ordered updatedAt desc', async () => {
    const page = await RecipeQuery.library(userId, {
      category: 'dessert',
      sort: 'updatedAt',
      order: 'desc',
      limit: 10,
    })
    expect(ids(page)).toEqual(['dessert-b', 'dessert-a'])
    expect(page.hasMore).toBe(false)
  })

  test('combines a type facet with the category filter', async () => {
    const page = await RecipeQuery.library(userId, {
      type: 'thermomix',
      category: 'main',
      sort: 'updatedAt',
      order: 'desc',
      limit: 10,
    })
    expect(ids(page)).toEqual(['dish-new'])
  })

  test('pins the order to updatedAt desc even when an ascending sort is requested', async () => {
    // The category filter coerces the page to updatedAt desc. Requesting the
    // opposite (updatedAt ASC) proves the coercion actually fires: without it the
    // page would come back ascending (['dessert-a', 'dessert-b']).
    const page = await RecipeQuery.library(userId, {
      category: 'dessert',
      sort: 'updatedAt',
      order: 'asc',
      limit: 10,
    })
    expect(ids(page)).toEqual(['dessert-b', 'dessert-a'])
  })

  test('paginates within a category via the cursor', async () => {
    // A third dessert so a limit-2 page leaves a remainder to fetch. Ordered
    // updatedAt desc: dessert-b(4000), dessert-c(3000), dessert-a(2000).
    seedRecipe('dessert-c', { type: 'dish', category: 'dessert', updatedAt: 3000 })
    const page1 = await RecipeQuery.library(userId, {
      category: 'dessert',
      sort: 'updatedAt',
      order: 'desc',
      limit: 2,
    })
    expect(ids(page1)).toEqual(['dessert-b', 'dessert-c'])
    expect(page1.hasMore).toBe(true)

    const page2 = await RecipeQuery.library(userId, {
      category: 'dessert',
      sort: 'updatedAt',
      order: 'desc',
      limit: 2,
      after: 'dessert-c' as RecipeId,
    })
    expect(ids(page2)).toEqual(['dessert-a'])
    expect(page2.hasMore).toBe(false)
  })
})

describe('RecipeQuery.library — limit clamp', () => {
  beforeEach(() => {
    for (let i = 0; i < 3; i++) seedRecipe(`r${i}`, { category: 'main', updatedAt: 1000 + i })
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
    for (let i = 3; i < 51; i++) seedRecipe(`r${i}`, { category: 'main', updatedAt: 1000 + i })
    const page = await RecipeQuery.library(userId, { sort: 'updatedAt', order: 'desc', limit: 999 })
    expect(page.items.length).toBe(50)
    expect(page.hasMore).toBe(true)
  })
})
