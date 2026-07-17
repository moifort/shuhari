import { builder } from './builder'

// Custom scalars must be registered before any type that references them.
import './scalars'

// Recipe domain (the aggregate root: Recipe + Version types)
import '~/domain/recipe/infrastructure/graphql/enums'
import '~/domain/recipe/infrastructure/graphql/types'
import '~/domain/recipe/infrastructure/graphql/inputs'
import '~/domain/recipe/infrastructure/graphql/queries'
import '~/domain/recipe/infrastructure/graphql/mutations'

// Trial domain (extends RecipeType with .trials, VersionType with aggregates)
import '~/domain/trial/infrastructure/graphql/types'
import '~/domain/trial/infrastructure/graphql/inputs'
import '~/domain/trial/infrastructure/graphql/mutations'
import '~/domain/trial/infrastructure/graphql/queries'

// Proposal domain (extends RecipeType with .pendingProposal)
import '~/domain/proposal/infrastructure/graphql/types'
import '~/domain/proposal/infrastructure/graphql/inputs'
import '~/domain/proposal/infrastructure/graphql/mutations'

// Home domain (read-only aggregation)
import '~/domain/home/infrastructure/graphql/types'
import '~/domain/home/infrastructure/graphql/queries'

// Changelog (application release notes)
import '~/domain/changelog/infrastructure/graphql/types'
import '~/domain/changelog/infrastructure/graphql/queries'

// Portability (export and import of user data)
import '~/domain/portability/infrastructure/graphql/types'
import '~/domain/portability/infrastructure/graphql/queries'
import '~/domain/portability/infrastructure/graphql/mutations'

// AI import (Gemini recipe extraction)
import '~/system/ai/graphql/types'
import '~/system/ai/graphql/mutations'

export const schema = builder.toSchema()
