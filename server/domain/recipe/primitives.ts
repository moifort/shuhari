import { make } from 'ts-brand'
import { z } from 'zod'
import {
  type IngredientName as IngredientNameType,
  type IngredientQuantity as IngredientQuantityType,
  type ParamKey as ParamKeyType,
  type ParamValue as ParamValueType,
  RECIPE_TYPE_VALUES,
  type RecipeId as RecipeIdType,
  type RecipeSubtitle as RecipeSubtitleType,
  type RecipeTitle as RecipeTitleType,
  type RecipeType as RecipeTypeType,
  type StepText as StepTextType,
  type TmxSpeed as TmxSpeedType,
  type TmxTemperature as TmxTemperatureType,
  type TmxTime as TmxTimeType,
  type VersionNumber as VersionNumberType,
  type VersionOriginKind as VersionOriginKindType,
} from '~/domain/recipe/types'

export const RecipeId = (value: unknown) => {
  const v = z.string().uuid().parse(value)
  return make<RecipeIdType>()(v)
}

export const randomRecipeId = () => RecipeId(crypto.randomUUID())

export const RecipeType = (value: unknown) =>
  z.enum(RECIPE_TYPE_VALUES).parse(value) as RecipeTypeType

export const RecipeTitle = (value: unknown) => {
  const v = z.string().trim().min(1).max(200).parse(value)
  return make<RecipeTitleType>()(v)
}

export const RecipeSubtitle = (value: unknown) => {
  const v = z.string().trim().min(1).max(200).parse(value)
  return make<RecipeSubtitleType>()(v)
}

export const VersionNumber = (value: unknown) => {
  const v = z
    .preprocess((n) => (typeof n === 'string' ? Number(n) : n), z.number().int().min(1))
    .parse(value)
  return make<VersionNumberType>()(v)
}

export const ParamKey = (value: unknown) => {
  const v = z.string().trim().min(1).max(60).parse(value)
  return make<ParamKeyType>()(v)
}

export const ParamValue = (value: unknown) => {
  const v = z.string().trim().min(1).max(120).parse(value)
  return make<ParamValueType>()(v)
}

export const IngredientName = (value: unknown) => {
  // 120, not 60: AI imports legitimately produce descriptive names
  // ("Pommes de terre farineuses, épluchées et coupées en rondelles (0,5 cm)").
  const v = z.string().trim().min(1).max(120).parse(value)
  return make<IngredientNameType>()(v)
}

export const IngredientQuantity = (value: unknown) => {
  const v = z.string().trim().min(1).max(60).parse(value)
  return make<IngredientQuantityType>()(v)
}

export const StepText = (value: unknown) => {
  const v = z.string().trim().min(1).max(300).parse(value)
  return make<StepTextType>()(v)
}

export const TmxTime = (value: unknown) => {
  const v = z.string().trim().min(1).max(20).parse(value)
  return make<TmxTimeType>()(v)
}

export const TmxTemperature = (value: unknown) => {
  const v = z.string().trim().min(1).max(20).parse(value)
  return make<TmxTemperatureType>()(v)
}

export const TmxSpeed = (value: unknown) => {
  const v = z.string().trim().min(1).max(20).parse(value)
  return make<TmxSpeedType>()(v)
}

export const VersionOriginKind = (value: unknown) =>
  z.enum(['import', 'ai-proposal', 'manual']).parse(value) as VersionOriginKindType
