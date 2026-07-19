import { VersionNumber as toVersionNumber } from '~/domain/recipe/primitives'
import {
  DISH_CATEGORY_VALUES,
  type DishCategory,
  type Note,
  type RecipeVersion,
  type StepText,
  type TmxSettings,
  type TmxSpeed,
  type TmxTemperature,
  type TmxTime,
  type VersionNumber,
} from '~/domain/recipe/types'

// A version that has been cooked and rated (a `note` is present) — the subset
// bestNote ranks over.
type RatedVersion = RecipeVersion & { note: Note }
const isRated = (version: RecipeVersion): version is RatedVersion => version.note !== null

// The library's category sort follows the course order (Entrée → Plat → Dessert →
// Soupe → Sauce → Boulangerie), not the alphabetical order of the enum values. We
// denormalize that business rank (0..5) onto each recipe document so Firestore can
// order by it with a stable cursor — sorting client-side would break pagination.
export const categoryRank = (category: DishCategory): number =>
  DISH_CATEGORY_VALUES.indexOf(category)

export const nextVersionNumber = (versionCount: VersionNumber) => toVersionNumber(versionCount + 1)

// The recipe's best essai across its cooked versions, or null when none was ever
// tried. Highest note wins; a tie breaks toward the most recent version (highest
// number), so the freshest high score is the reference. Returns the version itself
// so callers keep both the note and its lineage position.
export const bestNote = (versions: RecipeVersion[]): RecipeVersion | null =>
  versions
    .filter(isRated)
    .reduce<RatedVersion | null>(
      (best, version) =>
        best === null ||
        version.note > best.note ||
        (version.note === best.note && version.number > best.number)
          ? version
          : best,
      null,
    )

// Which version the fiche opens on when entered from the home. Priority:
//   1. the "essai en cours" — the most recent version based on the best-noted one
//      (an iteration cooked or awaiting a cook off the current reference);
//   2. failing that, the best-noted version itself;
//   3. failing any rating at all, the latest version (a brand-new, untried recipe).
// Assumes a non-empty lineage (a recipe always owns at least its v1).
export const versionToOpen = (versions: RecipeVersion[]): RecipeVersion => {
  const latest = versions.reduce((a, b) => (b.number > a.number ? b : a))
  const best = bestNote(versions)
  if (best === null) return latest
  const essaiEnCours = versions
    .filter((version) => version.basedOn === best.number)
    .reduce<RecipeVersion | null>((a, b) => (a === null || b.number > a.number ? b : a), null)
  return essaiEnCours ?? best
}

// Thermomix settings are only usable when they mirror the steps one-to-one and
// at least one step actually carries a setting; anything else is dropped so the
// stored version never holds a misaligned or empty parallel array. Entries
// without any actual setting (reverse alone carries none when false) are
// normalized to null.
export const alignedTmxSteps = (steps: StepText[], tmxSteps: (TmxSettings | null)[]) => {
  if (tmxSteps.length !== steps.length) return []
  const normalized = tmxSteps.map((s) => (s && !emptySettings(s) ? s : null))
  return normalized.some((s) => s !== null) ? normalized : []
}

const emptySettings = (s: TmxSettings) =>
  s.time === undefined && s.temperature === undefined && s.speed === undefined && !s.reverse

// One step's Thermomix settings as they arrive from a GraphQL input or a branded
// AI proposal: each field may be present, null or absent. A `null`/`undefined`
// entry stands for a plain (non-Thermomix) step.
export type LooseTmxSettings = {
  time?: TmxTime | null
  temperature?: TmxTemperature | null
  speed?: TmxSpeed | null
  reverse?: boolean | null
}

// Normalize loose per-step settings into clean TmxSettings, dropping absent/null
// keys. `reverse` is kept only when true — false carries no information (a step
// whose only "setting" is reverse:false is not a Thermomix step). The single home
// for this rule so the GraphQL and AI-proposal paths can never diverge;
// `alignedTmxSteps` then decides whether the parallel array is kept at all.
export const toTmxSettings = (
  entries: (LooseTmxSettings | null | undefined)[],
): (TmxSettings | null)[] =>
  entries.map((entry) =>
    entry
      ? {
          ...(entry.time ? { time: entry.time } : {}),
          ...(entry.temperature ? { temperature: entry.temperature } : {}),
          ...(entry.speed ? { speed: entry.speed } : {}),
          ...(entry.reverse ? { reverse: entry.reverse } : {}),
        }
      : null,
  )
