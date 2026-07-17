import SchemaBuilder from '@pothos/core'
import { GraphQLScalarType } from 'graphql'
import type { H3Event } from 'h3'
import type {
  IngredientName,
  IngredientQuantity,
  Note,
  RecipeId,
  RecipeSubtitle,
  RecipeTitle,
  Remarks,
  StepText,
  TmxSpeed,
  TmxTemperature,
  TmxTime,
  VersionNumber,
} from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import type { RecipeSatelliteLoaders } from './loaders'

export type GraphQLContext = {
  event: H3Event
  userId: UserId
  loaders: RecipeSatelliteLoaders
}

const DateTimeScalar = new GraphQLScalarType({
  name: 'DateTime',
  description: 'ISO 8601 date-time string',
  serialize: (value: unknown) => (value instanceof Date ? value.toISOString() : value),
  parseValue: (value: unknown) => new Date(value as string),
})

export const builder = new SchemaBuilder<{
  Context: GraphQLContext
  DefaultFieldNullability: false
  Scalars: {
    DateTime: { Input: Date; Output: Date }
    UserId: { Input: UserId; Output: UserId }
    RecipeId: { Input: RecipeId; Output: RecipeId }
    RecipeTitle: { Input: RecipeTitle; Output: RecipeTitle }
    RecipeSubtitle: { Input: RecipeSubtitle; Output: RecipeSubtitle }
    VersionNumber: { Input: VersionNumber; Output: VersionNumber }
    Note: { Input: Note; Output: Note }
    IngredientName: { Input: IngredientName; Output: IngredientName }
    IngredientQuantity: { Input: IngredientQuantity; Output: IngredientQuantity }
    StepText: { Input: StepText; Output: StepText }
    TmxTime: { Input: TmxTime; Output: TmxTime }
    TmxTemperature: { Input: TmxTemperature; Output: TmxTemperature }
    TmxSpeed: { Input: TmxSpeed; Output: TmxSpeed }
    Remarks: { Input: Remarks; Output: Remarks }
  }
}>({
  defaultFieldNullability: false,
})

builder.addScalarType('DateTime', DateTimeScalar)
builder.queryType({})
builder.mutationType({})
