import { builder } from '~/domain/shared/graphql/builder'

export const RecipeTypeEnum = builder.enumType('RecipeType', {
  description: 'The kind of culinary experiment — a cooked dish or a Thermomix recipe',
  values: {
    PLAT: { value: 'plat' },
    TMX: { value: 'tmx' },
  } as const,
})

export const DishCategoryEnum = builder.enumType('DishCategory', {
  description: 'The course a dish belongs to — aggregate-level identity, drives library sorting',
  values: {
    ENTREE: { value: 'entree' },
    PLAT: { value: 'plat' },
    DESSERT: { value: 'dessert' },
    SOUPE: { value: 'soupe' },
    SAUCE: { value: 'sauce' },
    BOULANGERIE: { value: 'boulangerie' },
  } as const,
})

export const VersionOriginKindEnum = builder.enumType('VersionOriginKind', {
  description: 'How a version came to exist',
  values: {
    IMPORT: { value: 'import' },
    AI_PROPOSAL: { value: 'ai-proposal' },
    MANUAL: { value: 'manual' },
  } as const,
})
