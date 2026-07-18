import { builder } from '~/domain/shared/graphql/builder'

export const RecipeTypeEnum = builder.enumType('RecipeType', {
  description:
    'The kind of culinary experiment. Fixed at import, it decides how a version is displayed ' +
    'and how the AI is allowed to iterate on it.',
  values: {
    PLAT: { value: 'plat', description: 'A cooked dish — steps are plain text' },
    TMX: {
      value: 'tmx',
      description: 'A Thermomix recipe — each step also carries machine settings (time/temp/speed)',
    },
  } as const,
})

export const DishCategoryEnum = builder.enumType('DishCategory', {
  description:
    'The course a dish belongs to. Detected once at import, shared by every version, and used ' +
    'to group and sort the library.',
  values: {
    ENTREE: { value: 'entree', description: 'Starter' },
    PLAT: { value: 'plat', description: 'Main course' },
    DESSERT: { value: 'dessert', description: 'Dessert' },
    SOUPE: { value: 'soupe', description: 'Soup' },
    SAUCE: { value: 'sauce', description: 'Sauce or condiment' },
    BOULANGERIE: { value: 'boulangerie', description: 'Bread and bakery' },
  } as const,
})

export const RecipeSortEnum = builder.enumType('RecipeSort', {
  description: 'Field the paginated recipe library is ordered by',
  values: {
    UPDATED_AT: { value: 'updatedAt', description: 'Most recently modified first (honours order)' },
    CATEGORY: {
      value: 'category',
      description:
        'Dish course order (Entrée → Plat → Dessert → Soupe → Sauce → Boulangerie), ' +
        'most recently modified first within a course',
    },
  } as const,
})

export const SortOrderEnum = builder.enumType('SortOrder', {
  description: 'Sort direction',
  values: {
    ASC: { value: 'asc', description: 'Ascending (oldest / lowest first)' },
    DESC: { value: 'desc', description: 'Descending (newest / highest first)' },
  } as const,
})

export const VersionOriginKindEnum = builder.enumType('VersionOriginKind', {
  description: 'Where a version came from — how this entry in the lineage was born',
  values: {
    IMPORT: {
      value: 'import',
      description: 'The original v1, created when the recipe was imported',
    },
    AI_PROPOSAL: {
      value: 'ai-proposal',
      description: 'An iteration the AI drafted from the previous essai and the cook accepted',
    },
    MANUAL: { value: 'manual', description: 'A version the cook wrote by hand, without the AI' },
  } as const,
})
