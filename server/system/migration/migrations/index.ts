import type { Migration } from '~/system/migration/types'

// Forward-only migrations, applied in order by the runner. Register new
// migrations here. Empty until the first schema evolution ships.
export const migrations: Migration[] = []
