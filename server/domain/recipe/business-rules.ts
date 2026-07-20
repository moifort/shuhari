import { VersionNumber as toVersionNumber } from '~/domain/recipe/primitives'
import {
  DISH_CATEGORY_VALUES,
  type DishCategory,
  type Rating,
  type RecipeVersion,
  type VersionNumber,
} from '~/domain/recipe/types'

// A version that has been cooked and rated (a `rating` is present) — the subset
// bestRating ranks over.
type RatedVersion = RecipeVersion & { rating: Rating }
const isRated = (version: RecipeVersion): version is RatedVersion => version.rating !== undefined

// The library's category sort follows the course order (starter → main → dessert →
// soup → sauce → baking), not the alphabetical order of the enum values. We
// denormalize that business rank (0..5) onto each recipe document so Firestore can
// order by it with a stable cursor — sorting client-side would break pagination.
export const categoryRank = (category: DishCategory): number =>
  DISH_CATEGORY_VALUES.indexOf(category)

export const nextVersionNumber = (lastVersionNumber: VersionNumber) =>
  toVersionNumber(lastVersionNumber + 1)

// The recipe's best attempt across its cooked versions, or nothing when none was
// ever tried. Highest rating wins; a tie breaks toward the most recent version
// (highest number), so the freshest high score is the reference. Returns the version
// itself so callers keep both the rating and its lineage position.
export const bestRating = (versions: RecipeVersion[]): RecipeVersion | undefined =>
  versions
    .filter(isRated)
    .reduce<RatedVersion | undefined>(
      (best, version) =>
        best === undefined ||
        version.rating > best.rating ||
        (version.rating === best.rating && version.number > best.number)
          ? version
          : best,
      undefined,
    )

// Which version the recipe sheet opens on when entered from the home: the best-rated
// one, falling back to the latest version when nothing was ever cooked (a brand-new,
// untried recipe). A version that still owes a cook is never opened — the sheet shows
// what is known to work, and the versions waiting to be tried are reached through the
// flask CTA. Assumes a non-empty lineage (a recipe always owns at least its v1).
export const versionToOpen = (versions: RecipeVersion[]): RecipeVersion =>
  bestRating(versions) ?? versions.reduce((a, b) => (b.number > a.number ? b : a))
