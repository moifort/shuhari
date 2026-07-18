import { builder } from './builder'

// Custom scalars must be registered before any type that references them.
import './scalars'

// Recipe domain (the aggregate root: Recipe + Version types, incl. the essai
// outcome folded onto each version and the recordEssai mutation)
import '~/domain/recipe/infrastructure/graphql/enums'
import '~/domain/recipe/infrastructure/graphql/types'
import '~/domain/recipe/infrastructure/graphql/inputs'
import '~/domain/recipe/infrastructure/graphql/queries'
import '~/domain/recipe/infrastructure/graphql/mutations'

// Proposition domain (ephemeral AI propositions — import preview + next-version
// suggestions; request/accept + analyzeImport mutations)
import '~/domain/proposition/infrastructure/graphql/types'
import '~/domain/proposition/infrastructure/graphql/inputs'
import '~/domain/proposition/infrastructure/graphql/mutations'

// Changelog (application release notes)
import '~/system/changelog/infrastructure/graphql/types'
import '~/system/changelog/infrastructure/graphql/queries'

// Portability (export and import of user data)
import '~/system/portability/infrastructure/graphql/types'
import '~/system/portability/infrastructure/graphql/queries'
import '~/system/portability/infrastructure/graphql/mutations'

export const schema = builder.toSchema()
