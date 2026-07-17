import { GraphQLError } from 'graphql'
import { ZodError } from 'zod'
import {
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
} from '~/domain/recipe/primitives'
import { UserId } from '~/domain/shared/primitives'
import { builder } from './builder'

const validatedParse =
  <T>(name: string, parse: (value: unknown) => T) =>
  (value: unknown): T => {
    try {
      return parse(value)
    } catch (error) {
      const message =
        error instanceof ZodError
          ? error.issues.map(({ message }) => message).join(', ')
          : `Invalid ${name}`
      throw new GraphQLError(`Invalid value for ${name}: ${message}`, {
        extensions: { code: 'BAD_USER_INPUT' },
      })
    }
  }

builder.scalarType('UserId', {
  description: 'Firebase Auth user identifier',
  serialize: (value) => value as string,
  parseValue: validatedParse('UserId', UserId),
})

builder.scalarType('RecipeId', {
  description: 'Recipe unique identifier (UUID v4)',
  serialize: (value) => value as string,
  parseValue: validatedParse('RecipeId', RecipeId),
})

builder.scalarType('RecipeTitle', {
  description: 'Recipe title (1-200 chars)',
  serialize: (value) => value as string,
  parseValue: validatedParse('RecipeTitle', RecipeTitle),
})

builder.scalarType('RecipeSubtitle', {
  description: 'Recipe subtitle (1-200 chars)',
  serialize: (value) => value as string,
  parseValue: validatedParse('RecipeSubtitle', RecipeSubtitle),
})

builder.scalarType('VersionNumber', {
  description: 'Version number in a recipe lineage (>= 1)',
  serialize: (value) => value as number,
  parseValue: validatedParse('VersionNumber', VersionNumber),
})

builder.scalarType('Note', {
  description: 'Essai rating (integer 1..5)',
  serialize: (value) => value as number,
  parseValue: validatedParse('Note', Note),
})

builder.scalarType('IngredientName', {
  description: 'Recipe ingredient name (1-120 chars)',
  serialize: (value) => value as string,
  parseValue: validatedParse('IngredientName', IngredientName),
})

builder.scalarType('IngredientQuantity', {
  description: 'Recipe ingredient quantity with unit (1-60 chars)',
  serialize: (value) => value as string,
  parseValue: validatedParse('IngredientQuantity', IngredientQuantity),
})

builder.scalarType('StepText', {
  description: 'A short recipe step (1-300 chars)',
  serialize: (value) => value as string,
  parseValue: validatedParse('StepText', StepText),
})

builder.scalarType('TmxTime', {
  description: 'Thermomix step duration, display-oriented (e.g. "3 min", "30 s")',
  serialize: (value) => value as string,
  parseValue: validatedParse('TmxTime', TmxTime),
})

builder.scalarType('TmxTemperature', {
  description: 'Thermomix step temperature, display-oriented (e.g. "100°C", "Varoma")',
  serialize: (value) => value as string,
  parseValue: validatedParse('TmxTemperature', TmxTemperature),
})

builder.scalarType('TmxSpeed', {
  description: 'Thermomix step speed, display-oriented (e.g. "5", "pétrin", "turbo")',
  serialize: (value) => value as string,
  parseValue: validatedParse('TmxSpeed', TmxSpeed),
})

builder.scalarType('Remarks', {
  description: 'Free-form essai remarks (up to 2000 chars)',
  serialize: (value) => value as string,
  parseValue: validatedParse('Remarks', Remarks),
})
