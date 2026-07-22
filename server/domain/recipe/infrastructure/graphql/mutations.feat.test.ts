import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeFirebase, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', fakeFirebase)

const { schema } = await import('~/domain/shared/graphql/schema')
const { recipeSatelliteLoaders } = await import('~/domain/shared/graphql/loaders')

const userId = 'user-1' as UserId

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
})

// One request = one loader set, exactly as routes/graphql.ts builds it.
const execute = (source: string) =>
  graphql({
    schema,
    source,
    contextValue: { userId, event: undefined as never, loaders: recipeSatelliteLoaders() },
  })

const createLasagna = `
  mutation {
    createRecipe(input: {
      type: DISH
      category: MAIN
      title: "Lasagnes de mamie"
      sourceLabel: "Marmiton"
      content: { dish: {
        ingredients: [{ name: "Farine", quantity: "250 g" }]
        steps: ["Monter les couches", "Enfourner à 200°C"]
      } }
    }) {
      id
      title
      category
      versionCount
      bestRating
      versionToOpen { number tried rating }
    }
  }
`

const createdId = async () => {
  const result = await execute(createLasagna)
  expect(result.errors).toBeUndefined()
  return (result.data as { createRecipe: { id: string } }).createRecipe.id
}

describe('createRecipe mutation', () => {
  test('turns an import into a recipe opened on its untried v1', async () => {
    const result = await execute(createLasagna)
    expect(result.errors).toBeUndefined()
    expect(result.data?.createRecipe).toMatchObject({
      title: 'Lasagnes de mamie',
      category: 'MAIN',
      versionCount: 1,
      // Nothing cooked yet: no rating anywhere, and v1 is the version to open.
      bestRating: null,
      versionToOpen: { number: 1, tried: false, rating: null },
    })

    const id = (result.data as { createRecipe: { id: string } }).createRecipe.id
    expect(fake.snapshot('recipes').get(id)?.type).toBe('dish')
    expect(fake.snapshot('recipe-versions').get(`${id}_1`)?.origin).toEqual({
      kind: 'import',
      detail: 'Marmiton',
    })
  })

  test('refuses a body that does not match the recipe type', async () => {
    const result = await execute(`
      mutation {
        createRecipe(input: {
          type: DISH
          category: MAIN
          title: "Lasagnes de mamie"
          content: { thermomix: { ingredients: [], steps: [{ text: "Mixer", settings: {} }] } }
        }) { id }
      }
    `)
    expect(result.errors?.[0]?.extensions?.code).toBe('CONTENT_TYPE_MISMATCH')
  })
})

describe('updateRecipe mutation', () => {
  test('renames, refiles and marks as favourite in one call', async () => {
    const id = await createdId()
    const result = await execute(`
      mutation {
        updateRecipe(id: "${id}", input: { title: "Lasagnes de nonna", category: DESSERT, favorite: true }) {
          title
          category
          favorite
        }
      }
    `)
    expect(result.errors).toBeUndefined()
    expect(result.data?.updateRecipe).toMatchObject({
      title: 'Lasagnes de nonna',
      category: 'DESSERT',
      favorite: true,
    })
  })

  test('surfaces an unknown recipe as NOT_FOUND', async () => {
    const result = await execute(`
      mutation { updateRecipe(id: "11111111-1111-4111-8111-111111111111", input: { title: "Rien" }) { title } }
    `)
    expect(result.errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
  })
})

describe('recordAttempt mutation', () => {
  test('lands the outcome on the version that was cooked', async () => {
    const id = await createdId()
    const result = await execute(`
      mutation {
        recordAttempt(input: { recipeId: "${id}", versionNumber: 1, rating: 4 }) {
          number
          rating
          tried
        }
      }
    `)
    expect(result.errors).toBeUndefined()
    expect(result.data?.recordAttempt).toMatchObject({ number: 1, rating: 4, tried: true })
    expect(fake.snapshot('recipe-versions').get(`${id}_1`)?.rating).toBe(4)
  })

  test('rejects a rating outside 1..5 before it reaches the domain', async () => {
    const id = await createdId()
    const result = await execute(`
      mutation {
        recordAttempt(input: { recipeId: "${id}", versionNumber: 1, rating: 9 }) { number }
      }
    `)
    expect(result.errors?.[0]?.extensions?.code).toBe('BAD_USER_INPUT')
  })
})

describe('updateTips mutation', () => {
  test('rewrites the tips in place, without creating a version', async () => {
    const id = await createdId()
    const result = await execute(`
      mutation {
        updateTips(recipeId: "${id}", versionNumber: 1, tips: ["Servir avec du riz"]) {
          number
          tips
        }
      }
    `)
    expect(result.errors).toBeUndefined()
    expect(result.data?.updateTips).toMatchObject({ number: 1, tips: ['Servir avec du riz'] })
    expect([...fake.snapshot('recipe-versions').keys()]).toEqual([`${id}_1`])
  })
})

describe('updateWarnings mutation', () => {
  test('rewrites the cautions in place, without touching the lineage', async () => {
    const id = await createdId()
    const result = await execute(`
      mutation {
        updateWarnings(recipeId: "${id}", warnings: ["Mettre le fouet dès le début"]) {
          warnings
        }
      }
    `)
    expect(result.errors).toBeUndefined()
    expect(result.data?.updateWarnings).toMatchObject({
      warnings: ['Mettre le fouet dès le début'],
    })
    expect([...fake.snapshot('recipe-versions').keys()]).toEqual([`${id}_1`])
  })

  test('full-replacement: [] clears the banner', async () => {
    const id = await createdId()
    await execute(
      `mutation { updateWarnings(recipeId: "${id}", warnings: ["Sortir le beurre avant"]) { warnings } }`,
    )
    const result = await execute(
      `mutation { updateWarnings(recipeId: "${id}", warnings: []) { warnings } }`,
    )
    expect(result.errors).toBeUndefined()
    expect(result.data?.updateWarnings).toMatchObject({ warnings: [] })
  })

  test('surfaces an unknown recipe as NOT_FOUND', async () => {
    const result = await execute(`
      mutation { updateWarnings(recipeId: "11111111-1111-4111-8111-111111111111", warnings: []) { warnings } }
    `)
    expect(result.errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
  })
})

describe('deleteRecipe mutation', () => {
  test('erases the recipe and its whole lineage', async () => {
    const id = await createdId()
    const result = await execute(`mutation { deleteRecipe(id: "${id}") }`)
    expect(result.errors).toBeUndefined()
    expect(result.data?.deleteRecipe).toBe(true)
    expect(fake.snapshot('recipes').size).toBe(0)
    expect(fake.snapshot('recipe-versions').size).toBe(0)
  })

  test('surfaces an unknown recipe as NOT_FOUND', async () => {
    const result = await execute(
      `mutation { deleteRecipe(id: "11111111-1111-4111-8111-111111111111") }`,
    )
    expect(result.errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
  })
})
