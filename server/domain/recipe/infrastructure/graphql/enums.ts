import { builder } from '~/domain/shared/graphql/builder'

export const RecipeTypeEnum = builder.enumType('RecipeType', {
  description: 'The kind of culinary experiment — drives the one-variable rule',
  values: {
    CAFE: { value: 'cafe' },
    COCKTAIL: { value: 'cocktail' },
    PLAT: { value: 'plat' },
    TMX: { value: 'tmx' },
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
