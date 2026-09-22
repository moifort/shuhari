import type { Transaction } from 'firebase-admin/firestore'
import {
  favorited,
  lastWorkedOn,
  methodMatchesType,
  nextVersionNumber,
  standing,
  tagsAtBirth,
  tally,
  withComponents,
  withTags,
} from '~/domain/recipe/business-rules'
import type { CoffeeParameters } from '~/domain/recipe/content/coffee'
import type { OvenProfile } from '~/domain/recipe/content/oven'
import { thermomixSteps } from '~/domain/recipe/content/thermomix'
import type { VersionContent } from '~/domain/recipe/content/types'
import * as repository from '~/domain/recipe/infrastructure/repository'
import { COMPONENT_LIMITS, TAG_LIMITS } from '~/domain/recipe/limits'
import { type LooseVersionStep, randomRecipeId, VersionNumber } from '~/domain/recipe/primitives'
import type {
  BrewMethod,
  ComponentScale,
  DishCategory,
  Ingredient,
  Rating,
  Recipe,
  RecipeId,
  RecipeTitle,
  RecipeType,
  RecipeVersion,
  Remarks,
  StepText,
  Tag,
  Tip,
  VersionNumber as VersionNumberT,
  VersionOrigin,
  Warning,
} from '~/domain/recipe/types'
import { learnedVocabulary } from '~/domain/recipe/vocabulary'
import { Count } from '~/domain/shared/primitives'
import type { UserId } from '~/domain/shared/types'
import { transactionally } from '~/utils/firestore'

const FIRST_VERSION = VersionNumber(1)

// A coffee version teaches the cook's vocabulary — the waters, machines and beans
// its free-text fields carry — in the caller's transaction, so the two land
// together; a version of any other type teaches nothing. The vocabulary is read
// now and the write handed back, because a transaction reads everything before it
// writes anything.
const vocabularyLesson = async (userId: UserId, content: VersionContent, tx: Transaction) => {
  if (content.kind !== 'coffee') return async () => {}
  const current = await repository.findVocabulary(userId, tx)
  return () => repository.saveVocabulary(learnedVocabulary(current, content), tx)
}

// The recipe and its lineage, read inside the transaction the command writes in.
// Everything a command writes back on the recipe — the number it allocates, its
// date, its heart, its standing — is derived from that lineage, so reading it
// outside the transaction is how two commands landing together would each write a
// recipe that ignores the other (and, for `addVersion`, the same version twice).
const lineageOf = async (userId: UserId, recipeId: RecipeId, tx: Transaction) => {
  const recipe = await repository.findBy(userId, recipeId, tx)
  if (!recipe) return 'not-found' as const
  return { recipe, lineage: await repository.findVersionsOf(recipeId, tx) }
}

export type NewRecipeInput = {
  type: RecipeType
  category: DishCategory
  // Required on a coffee, rejected on anything else — see `methodMatchesType`.
  method?: BrewMethod
  title: RecipeTitle
  content: VersionContent
  tips: Tip[]
}

// The cook that came with an iteration: the rating, remarks and photo of the plate
// that was actually made. It rides along with the version it gave birth to, and is
// written on the plate the rating is a verdict on — the version it was made from,
// or the version created when that one IS what was made (see `NewVersionInput.cooked`).
// The remarks are optional: a change already eaten can be rated without a word.
export type Attempt = {
  rating: Rating
  remarks?: Remarks
  photoPath?: string
}

export type NewVersionInput = {
  change: string
  basedOn?: VersionNumberT
  why?: string
  content: VersionContent
  tips: Tip[]
  // The attempt that asked for this version — absent when an improvement asked for it
  // instead, with no cook behind it. It is recorded on `basedOn`, the version it was
  // cooked from, unless `cooked` says otherwise.
  attempt?: Attempt
  // This version has already been made: it writes down a change the cook applied at
  // the stove and ate, rather than one the AI suggests trying. It is therefore born
  // executed instead of owing a try, its origin is the cook's own hand (`manual`),
  // and the attempt — the verdict on that very plate — lands on IT, leaving the
  // version it iterates from exactly as it was.
  cooked?: true
}

// What can be retouched on the aggregate after creation. Anything left out stays as
// it was. The heart is not here: it is worn by a version (`updateFavorite`).
export type UpdateRecipeInput = {
  title?: RecipeTitle
  category?: DishCategory
  // Refiling a coffee under another brew method. Rejected on a recipe that is not
  // one — the type itself is never editable.
  method?: BrewMethod
  // The complete list the recipe is filed under from now on — full replacement, like
  // the warnings of a version: `[]` takes every tag off, leaving it out keeps them.
  tags?: Tag[]
}

// Which version becomes a recipe of its own, and under what name. The name is
// asked for rather than derived: two rows spelled the same in the library are two
// rows the cook cannot tell apart.
export type CopyVersionInput = {
  recipeId: RecipeId
  number: VersionNumberT
  title: RecipeTitle
}

export type RecordAttemptInput = {
  recipeId: RecipeId
  versionNumber: VersionNumberT
  rating: Rating
  // Absent when the cook was rated without a word written about it — a bare rating
  // ends the flow, it never asks the AI for anything.
  remarks?: Remarks
  photoPath?: string
}

export namespace RecipeCommand {
  // Create → recipe + its v1, written atomically. v1 is the original planned attempt
  // (no `basedOn`, it iterates on nothing) and awaits its first cook.
  export const create = async (userId: UserId, input: NewRecipeInput, sourceLabel?: string) => {
    // The body's discriminant must mirror the recipe type — a dish recipe cannot
    // carry Thermomix content and vice versa. Enforced here, no throw.
    if (input.content.kind !== input.type) return 'content-type-mismatch' as const
    // A brew method belongs to a coffee and to nothing else.
    if (!methodMatchesType(input)) return 'method-mismatch' as const
    const now = new Date()
    const recipe: Recipe = withTags(
      {
        id: randomRecipeId(),
        userId,
        type: input.type,
        // A coffee is a drink, whatever the AI guessed: the course axis says nothing
        // about it, its `method` is what the coffee tab reads on.
        category: input.type === 'coffee' ? 'drink' : input.category,
        ...(input.method ? { method: input.method } : {}),
        title: input.title,
        lastVersionNumber: FIRST_VERSION,
        createdAt: now,
        // `lastWorkedOn` of a lineage of one: the v1 born with it, this instant. No
        // lineage to read — there is nothing else in it yet.
        updatedAt: now,
        // Never cooked, never hearted: it stands last in its course until it is.
        standing: standing([]),
        // A lineage of one, never cooked and owing nothing: v1 is what was imported.
        versionCount: Count(1),
        toTestCount: Count(0),
      },
      // Filed from birth under what its type says of it — a Thermomix recipe says so.
      tagsAtBirth(input.type),
    )
    const origin: VersionOrigin = {
      kind: 'import',
      ...(sourceLabel ? { detail: sourceLabel } : {}),
    }
    return transactionally(async (tx) => {
      const teach = await vocabularyLesson(userId, input.content, tx)
      await repository.save(recipe, tx)
      await repository.saveVersion(firstVersion(recipe, origin, input), tx)
      await teach()
      return recipe
    })
  }

  // Copy one version into a recipe of its own — the cook has drifted far enough
  // from the recipe that the next attempt is no longer one of its iterations, and
  // wants its own page in the notebook. A full detachment: the copy carries the
  // version's content, its tips, the recipe's cautions and the verdict the plate
  // earned, and holds no pointer back. The lineage stays linear on both sides (no
  // fork, no `derivedFrom`): the only trace of where it came from is its origin
  // label, "Grandma's lasagna v3", the field an import fills with the site it read.
  // What is deliberately dropped is the lineage itself — the copy is a v1, so it
  // iterates on nothing and changes nothing. The source recipe is not written at
  // all, its date included: copying a version is not working on it.
  export const copyVersion = async (
    userId: UserId,
    input: CopyVersionInput,
  ): Promise<Recipe | 'not-found'> =>
    transactionally(async (tx) => {
      const source = await repository.findBy(userId, input.recipeId, tx)
      if (!source) return 'not-found' as const
      const version = await repository.findVersion(input.recipeId, input.number, tx)
      if (!version) return 'not-found' as const
      const now = new Date()
      const recipe: Recipe = {
        id: randomRecipeId(),
        userId,
        type: source.type,
        // Type, course and brew method are the recipe's identity, and the copy is the
        // same dish under another name: it lands in the same tab, ranked the same way.
        category: source.category,
        ...(source.method ? { method: source.method } : {}),
        title: input.title,
        lastVersionNumber: FIRST_VERSION,
        createdAt: now,
        // `lastWorkedOn` of a lineage of one, born this instant — whatever the age of
        // the plate copied.
        updatedAt: now,
        // The mirror of the single version below, which carries the heart over — and
        // the verdict with it, so the copy stands where that one plate puts it.
        ...(version.favorite ? { favorite: true as const } : {}),
        standing: standing([version]),
        // A lineage of one, carrying the verdict of the plate copied — and never
        // owing a try, like the copy below.
        ...(version.rating !== undefined ? { bestRating: version.rating } : {}),
        versionCount: Count(1),
        toTestCount: Count(0),
        // What the recipe is filed under is part of that identity, and comes along.
        ...(source.tags ? { tags: source.tags } : {}),
      }
      const copied: RecipeVersion = {
        userId,
        recipeId: recipe.id,
        number: FIRST_VERSION,
        createdAt: now,
        updatedAt: now,
        origin: { kind: 'import', detail: `${source.title} v${version.number}` },
        content: version.content,
        tips: version.tips,
        // The cautions travel with the plate: a gesture that ruins the dish ruins it
        // here too, under whatever name the copy was given. So does the heart — the
        // copy is the attempt the cook would make again, filed under another name.
        warnings: version.warnings,
        ...(version.favorite ? { favorite: true as const } : {}),
        // The verdict travels with the plate: a rating is about what came out of the
        // oven, not about the page it was written on, and the copy starts from
        // something known to work. A version never cooked copies as one never cooked
        // — and never as one owing a try: `toTest` is what an improvement asked for,
        // and nobody asked for this one.
        ...(version.executedAt ? { executedAt: version.executedAt } : {}),
        ...(version.rating !== undefined ? { rating: version.rating } : {}),
        ...(version.remarks ? { remarks: version.remarks } : {}),
        ...(version.photoPath ? { photoPath: version.photoPath } : {}),
      }
      const teach = await vocabularyLesson(userId, version.content, tx)
      await repository.save(recipe, tx)
      await repository.saveVersion(copied, tx)
      await teach()
      return recipe
    })

  // Accepted iteration → append version n+1 to the lineage, stamping the version it
  // was proposed from (`basedOn`). No reference/pending pointer to maintain: the
  // recipe just bumps its `lastVersionNumber` and restamps its date.
  // Who made the version decides the rest. Suggested by the AI, it has never been
  // made — it owes a try, and the cook that asked for it, when there was one, is
  // written on the version it iterates on: a rating is a verdict on the plate that
  // was made, and that plate is the previous version. Written down by the cook
  // instead (`cooked`), the plate that was made IS this one: it is born executed,
  // takes the attempt, and leaves the version it iterates from untouched.
  // The number is allocated inside the transaction: two acceptances landing together
  // would otherwise both read the same `lastVersionNumber` and write the same version.
  export const addVersion = async (userId: UserId, recipeId: RecipeId, input: NewVersionInput) =>
    transactionally(async (tx) => {
      const read = await lineageOf(userId, recipeId, tx)
      if (read === 'not-found') return read
      const { recipe, lineage } = read
      // The body's discriminant must mirror the recipe type (see `create`).
      if (input.content.kind !== recipe.type) return 'content-type-mismatch' as const
      const number = nextVersionNumber(recipe.lastVersionNumber)
      const now = new Date()
      // The version this one iterates on — what its cautions and its heart ride from.
      const base =
        input.basedOn === undefined
          ? undefined
          : lineage.find(({ number }) => number === input.basedOn)
      const born: RecipeVersion = {
        userId,
        recipeId,
        number,
        createdAt: now,
        // Born untouched: a version is last modified when it is created.
        updatedAt: now,
        // A change the cook applied at the stove is theirs, not the model's: the AI
        // only wrote down what they described.
        origin: { kind: input.cooked ? 'manual' : 'ai-proposal' },
        change: input.change,
        ...(input.basedOn !== undefined ? { basedOn: input.basedOn } : {}),
        ...(input.why ? { why: input.why } : {}),
        content: input.content,
        tips: input.tips,
        // The cautions of the version this one iterates on ride along: they are the
        // cook's own, written about a gesture rather than about one seasoning, and
        // nobody would think to write them down again after saying yes to a proposal.
        // Unlike `tips`, which the model regenerates with the content it just rewrote.
        // The linked recipes need no such carrying — they are held by the recipe, not
        // by the version, so an iteration never leaves them behind.
        warnings: base?.warnings ?? [],
        // The heart rides along too: the cook hearted this line of work, and the
        // iteration they just accepted is where it continues.
        ...(base?.favorite ? { favorite: true as const } : {}),
      }
      // A version already eaten is born executed — rated too, when the cook gave a
      // verdict; a version the AI suggests owes a try until someone makes it.
      const version: RecipeVersion = input.cooked
        ? input.attempt
          ? cooked(born, input.attempt, now)
          : { ...born, executedAt: now }
        : { ...born, toTest: true as const }
      // The cook that asked for this iteration, written on the version it was made
      // from — which stops owing a try, since it has just been made. Nothing to write
      // there when the version created is the one that was cooked.
      const cookedBase =
        !input.cooked && input.attempt && base ? cooked(base, input.attempt, now) : undefined
      const updated: Recipe = {
        ...restamped(recipe, written(lineage, cookedBase, version)),
        lastVersionNumber: number,
      }
      const teach = await vocabularyLesson(userId, input.content, tx)
      await repository.saveVersion(version, tx)
      if (cookedBase) await repository.saveVersion(cookedBase, tx)
      await repository.save(updated, tx)
      await teach()
      return updated
    })

  // Record the attempt outcome onto a version — the cook that asks for nothing more
  // (a rating, maybe a photo, no remarks). Overwritable: re-cooking the same version
  // simply rewrites its rating/remarks/executedAt in place. The outcome and the
  // recipe's restamped date land in one transaction (all-or-nothing).
  export const recordAttempt = async (
    userId: UserId,
    input: RecordAttemptInput,
  ): Promise<RecipeVersion | 'not-found'> =>
    // The whole lineage, not just the version cooked: the rating may hand the
    // reference over to another version, and the recipe is dated by that one.
    rewritten(userId, input.recipeId, input.versionNumber, (version) =>
      cooked(version, input, new Date()),
    )

  // Correct a version's rating in place — the cook is fixing the verdict they gave
  // (or giving one to a version they cooked without logging it), not re-cooking it:
  // the photo and the remarks of the attempt are left exactly as they were, unlike
  // `recordAttempt`, which replaces the whole outcome. A version that had never been
  // cooked becomes one that has: it gains its `executedAt` and stops owing a try, so
  // a rating and "still to test" are never both true.
  export const updateRating = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumberT,
    rating: Rating,
  ): Promise<RecipeVersion | 'not-found'> =>
    // Correcting a note can hand the reference over, like `recordAttempt`.
    rewritten(userId, recipeId, versionNumber, (version) => {
      const now = new Date()
      const { toTest: _cooked, ...rest } = version
      return { ...rest, rating, executedAt: version.executedAt ?? now, updatedAt: now }
    })

  // Rewrite a version's tips in place — the second overwritable part of the
  // envelope, beside the attempt outcome. No new version: the cook is refining the
  // advice on the version they have, not iterating on it. Full-replacement (the
  // accepted tips proposal is the complete list), plus the recipe's restamped date,
  // in one transaction.
  export const updateTips = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumberT,
    tips: Tip[],
  ): Promise<RecipeVersion | 'not-found'> =>
    rewritten(userId, recipeId, versionNumber, (version) => ({
      ...version,
      tips,
      updatedAt: new Date(),
    }))

  // Correct a coffee version's parameters in place — the cook is fixing what they
  // logged (a roast date read wrong, the grinder they forgot), not iterating on the
  // recipe: no version is created, and the brewing steps are left exactly as they
  // were. Full replacement, like `updateTips`: the edited parameters ARE the
  // complete set. Every free-text value typed also teaches the vocabulary, in the
  // same transaction.
  export const updateCoffeeParameters = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumberT,
    parameters: CoffeeParameters,
  ): Promise<RecipeVersion | 'not-found' | 'not-a-coffee'> =>
    rewritten(
      userId,
      recipeId,
      versionNumber,
      (version) =>
        // Parameters belong to a coffee and to nothing else — a dish has ingredients.
        version.content.kind !== 'coffee'
          ? ('not-a-coffee' as const)
          : { ...version, content: { ...parameters, kind: 'coffee' }, updatedAt: new Date() },
      { teaches: true },
    )

  // Correct one cooked version's shopping list in place — a quantity misread off a
  // photo, a line the import split in two. The counterpart of `updateOvenProfile` on
  // the ingredients: no version is created, because fixing what the recipe ALWAYS
  // said is not iterating on it, and the rating stays a verdict on the same plate.
  // Deliberately full-replacement, which is what makes adding, deleting and
  // reordering one operation instead of three.
  export const updateIngredients = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumberT,
    ingredients: Ingredient[],
  ): Promise<RecipeVersion | 'not-found' | 'not-a-cooked-recipe'> =>
    rewritten(userId, recipeId, versionNumber, (version) =>
      // A coffee has no shopping list — its dose, its water and its milk are parameters.
      version.content.kind === 'coffee'
        ? ('not-a-cooked-recipe' as const)
        : { ...version, content: { ...version.content, ingredients }, updatedAt: new Date() },
    )

  // Correct one cooked version's method in place — a step the import split in two,
  // an instruction read wrong. The steps arrive in one shape, text plus machine
  // settings, and the VERSION's kind decides what is kept: a dish is plain text and
  // has no machine, a Thermomix version pairs each text with its settings through
  // `thermomixSteps`, which stays the single home of that alignment rule.
  export const updateSteps = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumberT,
    steps: LooseVersionStep[],
  ): Promise<RecipeVersion | 'not-found' | 'not-a-cooked-recipe'> =>
    rewritten(userId, recipeId, versionNumber, (version) => {
      // A coffee has no method to write down — its dials say everything.
      if (version.content.kind === 'coffee') return 'not-a-cooked-recipe' as const
      const texts = steps.map(({ text }) => text)
      const content: VersionContent =
        version.content.kind === 'dish'
          ? { ...version.content, steps: texts }
          : {
              ...version.content,
              steps: thermomixSteps(
                texts,
                steps.map(({ settings }) => settings),
              ),
            }
      return { ...version, content, updatedAt: new Date() }
    })

  // Correct one cooked version's mise en place in place — a preparation the AI
  // forgot, one it got wrong, one the cook does differently. The AI writes it on
  // every version it produces, but the cook has the last word: full replacement, no
  // version created, the steps and the outcome untouched — like `updateSteps`.
  export const updateMiseEnPlace = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumberT,
    miseEnPlace: StepText[],
  ): Promise<RecipeVersion | 'not-found' | 'not-a-cooked-recipe'> =>
    rewritten(userId, recipeId, versionNumber, (version) =>
      // A coffee readies nothing by hand — its dials say everything.
      version.content.kind === 'coffee'
        ? ('not-a-cooked-recipe' as const)
        : { ...version, content: { ...version.content, miseEnPlace }, updatedAt: new Date() },
    )

  // Correct one cooked version's oven settings in place — a temperature read wrong,
  // a duration the source never stated. The counterpart of
  // `updateCoffeeParameters`: no version is created, because fixing what the recipe
  // ALWAYS said is not an iteration. Deliberately full-replacement, and `undefined`
  // clears the profile: a dish reclassified as never baking loses it outright rather
  // than keeping a hollow one.
  export const updateOvenProfile = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumberT,
    oven: OvenProfile | undefined,
  ): Promise<RecipeVersion | 'not-found' | 'not-a-cooked-recipe'> =>
    rewritten(userId, recipeId, versionNumber, (version) => {
      // A coffee has no oven — it is brewed, and its dials are its parameters.
      if (version.content.kind === 'coffee') return 'not-a-cooked-recipe' as const
      const { oven: _replaced, ...rest } = version.content
      const content: VersionContent = { ...rest, ...(oven ? { oven } : {}) }
      return { ...version, content, updatedAt: new Date() }
    })

  // Say that this recipe is made of another one — the bread's poolish, the ravioli's
  // pasta dough — and how much of it it takes (`scale`: 0.2 is a fifth of what that
  // recipe writes). Held by the RECIPE, so it holds for every version of it and no
  // iteration has to carry it forward.
  // Idempotent per linked recipe: linking one already linked rewrites its scale, which
  // is how the cook changes the weight. Nothing is versioned and nothing is redated —
  // saying what a recipe is made of is not cooking it, the same border `update` draws.
  export const linkComponent = async (
    userId: UserId,
    recipeId: RecipeId,
    component: RecipeId,
    scale: ComponentScale,
  ): Promise<Recipe | 'not-found' | 'self-reference' | 'too-many-components'> =>
    transactionally(async (tx) => {
      const recipe = await repository.findBy(userId, recipeId, tx)
      if (!recipe) return 'not-found' as const
      // A recipe made of itself is nonsense, and refused outright. Longer cycles
      // (A → B → A) are deliberately left alone: nothing resolves past one level, so
      // they are a navigation the cook can walk out of, not a loop.
      if (component === recipeId) return 'self-reference' as const
      // The linked recipe must be the cook's own. A stranger's answers 'not-found' like
      // any other — a code of its own would tell them it exists.
      if (!(await repository.findBy(userId, component, tx))) return 'not-found' as const
      const current = recipe.components ?? []
      const known = current.some(({ recipe: linked }) => linked === component)
      if (!known && current.length >= COMPONENT_LIMITS.perRecipe)
        return 'too-many-components' as const
      // Relinking keeps its place in the list: the cook is correcting a weight, not
      // linking something new, and a row that jumped to the bottom would say otherwise.
      const components = known
        ? current.map((c) => (c.recipe === component ? { recipe: component, scale } : c))
        : [...current, { recipe: component, scale }]
      return repository.save(withComponents(recipe, components), tx)
    })

  // Unlink one recipe from this one. Unlinking what was never linked succeeds on the
  // same list it was already in — there is nothing to report, and nothing changed.
  export const unlinkComponent = async (
    userId: UserId,
    recipeId: RecipeId,
    component: RecipeId,
  ): Promise<Recipe | 'not-found'> =>
    transactionally(async (tx) => {
      const recipe = await repository.findBy(userId, recipeId, tx)
      if (!recipe) return 'not-found' as const
      return repository.save(
        withComponents(
          recipe,
          (recipe.components ?? []).filter(({ recipe: linked }) => linked !== component),
        ),
        tx,
      )
    })

  // Rewrite a version's warnings in place — the third overwritable part of the
  // envelope, next to `updateTips`: pinning a caution on the plate is not iterating
  // on it, so no version is created. Full-replacement (the edited list is the
  // complete one), `[]` clears the banner, and the recipe's date is restamped like
  // any other touch the cook makes to a version.
  export const updateWarnings = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumberT,
    warnings: Warning[],
  ): Promise<RecipeVersion | 'not-found'> =>
    rewritten(userId, recipeId, versionNumber, (version) => ({
      ...version,
      warnings,
      updatedAt: new Date(),
    }))

  // The touches a cook can make to the aggregate itself: its name, its course, its
  // brew method or its tags. Each is optional — what is left out stays as it was. A
  // category or method change keeps the library's sort honest on its own:
  // `repository.save` re-derives `categoryRank` and `methodRank`. None of these is
  // cooking, so none of them moves the recipe's date: renaming or retagging a recipe
  // must not shuffle the notebook.
  export const update = async (userId: UserId, recipeId: RecipeId, input: UpdateRecipeInput) =>
    transactionally(async (tx) => {
      const recipe = await repository.findBy(userId, recipeId, tx)
      if (!recipe) return 'not-found' as const
      // A brew method belongs to a coffee: a dish never grows one, since the type
      // itself is not editable.
      if (input.method && recipe.type !== 'coffee') return 'method-mismatch' as const
      if (input.tags && input.tags.length > TAG_LIMITS.perRecipe) return 'too-many-tags' as const
      const retouched: Recipe = {
        ...recipe,
        ...(input.title ? { title: input.title } : {}),
        // A coffee stays a drink — refiling it means changing its method.
        ...(input.category && recipe.type !== 'coffee' ? { category: input.category } : {}),
        ...(input.method ? { method: input.method } : {}),
      }
      return repository.save(input.tags ? withTags(retouched, input.tags) : retouched, tx)
    })

  // Heart one version, or take the heart off it — the attempt the cook would make
  // again, not the page it sits on. The recipe's own `favorite` follows as the
  // derived mirror the library filters on (`favorited`), so hearting a version that
  // is not the one the recipe opens on still lists it under Favourites. Rewritten in
  // place: no version is created, and nothing about the plate changes — which is why
  // the version's own `updatedAt` stays put, unlike a caution or a tip. Hearting is
  // filing, not cooking, and filing must not shuffle the notebook.
  export const updateFavorite = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumberT,
    favorite: boolean,
  ): Promise<RecipeVersion | 'not-found'> =>
    rewritten(
      userId,
      recipeId,
      versionNumber,
      (version) => {
        // Spread without the flag, then put it back only if it holds — the
        // full-document write erases what is left out, which is what absence means here.
        const { favorite: _unhearted, ...rest } = version
        return { ...rest, ...(favorite ? { favorite: true as const } : {}) }
      },
      {
        // The mirror and the standing it decides, written by hand rather than through
        // `restamped`: the recipe's date must NOT move. The heart does move the recipe
        // within its course — to the top of it, which is what hearting asks for.
        restamp: (recipe, hearted) => {
          const { favorite: _mirrored, ...aggregate } = recipe
          return {
            ...aggregate,
            ...(favorited(hearted) ? { favorite: true as const } : {}),
            standing: standing(hearted),
          }
        },
      },
    )

  // Delete one version from the lineage. Its children are re-based onto the version
  // it iterated on (deleting a root leaves them iterating on nothing), so the chain
  // stays linear around the hole; the allocator (`lastVersionNumber`) never rolls
  // back, a deleted number is never reused. Deleting the sole version is deleting
  // the recipe — a recipe without a version does not exist.
  export const removeVersion = async (userId: UserId, recipeId: RecipeId, number: VersionNumberT) =>
    transactionally(async (tx) => {
      const read = await lineageOf(userId, recipeId, tx)
      if (read === 'not-found') return read
      const { recipe, lineage: versions } = read
      const target = versions.find(({ number: candidate }) => candidate === number)
      if (!target) return 'not-found' as const
      if (versions.length === 1) {
        repository.remove(recipeId, versions, tx)
        return undefined
      }
      // The children iterate on what the deleted version iterated on — its own base,
      // or nothing when it was a root. Bookkeeping, not an edit: their `updatedAt`
      // stays put, so the history does not move a version the cook never touched.
      const rebased = versions
        .filter(({ basedOn }) => basedOn === number)
        .map(({ basedOn: _deleted, ...rest }) => ({
          ...rest,
          ...(target.basedOn !== undefined ? { basedOn: target.basedOn } : {}),
        }))
      // Losing a version can hand the reference over to another one — deleting the
      // best-rated attempt re-dates the recipe by whatever now answers for it.
      const remaining = written(versions, ...rebased).filter(
        ({ number: candidate }) => candidate !== number,
      )
      // Deleting the hearted version can take the recipe out of the favourites lens,
      // the same way it can hand the reference over: both are derived from what is left.
      for (const child of rebased) await repository.saveVersion(child, tx)
      await repository.removeVersion(recipeId, number, tx)
      await repository.save(restamped(recipe, remaining), tx)
      return undefined
    })

  export const remove = async (userId: UserId, recipeId: RecipeId) =>
    transactionally(async (tx) => {
      const read = await lineageOf(userId, recipeId, tx)
      if (read === 'not-found') return read
      repository.remove(recipeId, read.lineage, tx)
      return undefined
    })

  // Portability: the cook's recipes and versions become exactly what the backup
  // carried. The restore writes before it deletes — see the repository: the
  // notebook is never emptied first, because a restore that dies halfway through
  // must not be what destroys the data it was recovering.
  // Each recipe's `standing` is derived again from the versions restored with it: a
  // backup written before the field existed carries none, and a recipe without it
  // drops out of the library's ordered query.
  export const replaceAllForUser = async (
    userId: UserId,
    recipes: Recipe[],
    versions: RecipeVersion[],
  ) =>
    repository.replaceAllByUser(
      userId,
      recipes.map((recipe) => {
        const lineage = versions.filter(({ recipeId }) => recipeId === recipe.id)
        const { bestRating: _stale, ...rest } = recipe
        return { ...rest, standing: standing(lineage), ...tally(lineage) }
      }),
      versions,
    )

  // Everything this domain holds on one cook, erased: the notebook and every
  // version in it. Called only when the account itself goes.
  export const forget = (userId: UserId): Promise<void> => repository.removeAllByUser(userId)

  // Rewrite one version in place — a verdict, a correction, a heart — and restamp the
  // recipe from the lineage as it will read once the write lands. No version is
  // created. `rewrite` answers the rewritten version, or the reason it refuses one
  // (a dish has no coffee dials); `restamp` is how the recipe follows, `restamped`
  // unless the rewrite must not move its date; `teaches` folds a coffee's free-text
  // values into the vocabulary, in the same transaction.
  const rewritten = <Rewritten extends RecipeVersion | string>(
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumberT,
    rewrite: (version: RecipeVersion) => Rewritten,
    {
      restamp = restamped,
      teaches = false,
    }: {
      restamp?: (recipe: Recipe, lineage: RecipeVersion[]) => Recipe
      teaches?: boolean
    } = {},
  ): Promise<Rewritten | 'not-found'> =>
    transactionally(async (tx) => {
      const read = await lineageOf(userId, recipeId, tx)
      if (read === 'not-found') return read
      const version = read.lineage.find(({ number }) => number === versionNumber)
      if (!version) return 'not-found' as const
      const updated = rewrite(version)
      if (typeof updated === 'string') return updated
      const teach = teaches ? await vocabularyLesson(userId, updated.content, tx) : undefined
      await repository.saveVersion(updated, tx)
      await repository.save(restamp(read.recipe, written(read.lineage, updated)), tx)
      await teach?.()
      return updated
    })

  // The aggregate as its lineage makes it read: everything the recipe document holds
  // about its versions is derived, never decided here. One place to do it, so a
  // command can never restamp one of them and forget the others.
  // `favorite` and `bestRating` are dropped rather than set to nothing — the
  // full-document write erases them, and absence is the single spelling of both.
  const restamped = (recipe: Recipe, versions: RecipeVersion[]): Recipe => {
    const { favorite: _derived, bestRating: _tallied, ...rest } = recipe
    return {
      ...rest,
      updatedAt: lastWorkedOn(versions),
      ...(favorited(versions) ? { favorite: true as const } : {}),
      standing: standing(versions),
      ...tally(versions),
    }
  }

  // The lineage as it will read once the pending writes land — the list the recipe's
  // date is computed from, since those documents are not saved yet. A written version
  // replaces the stored one of the same number, or joins the chain when it is new.
  const written = (lineage: RecipeVersion[], ...pending: (RecipeVersion | undefined)[]) => {
    const byNumber = new Map(lineage.map((version) => [version.number, version]))
    for (const version of pending) if (version) byNumber.set(version.number, version)
    return [...byNumber.values()]
  }

  // A version as it reads once it has been made: the outcome REPLACES whatever the
  // previous attempt left — a re-cook that leaves the photo or the remarks out erases
  // them rather than inheriting them — and the version stops owing a try. The one
  // shape of a cooked version, whether the cook was logged on its own
  // (`recordAttempt`) or rode along with the iteration it asked for (`addVersion`).
  const cooked = (
    version: RecipeVersion,
    attempt: { rating: Rating; remarks?: Remarks; photoPath?: string },
    now: Date,
  ): RecipeVersion => {
    const { photoPath: _replacedPhoto, remarks: _replacedRemarks, toTest: _owed, ...rest } = version
    return {
      ...rest,
      updatedAt: now,
      executedAt: now,
      rating: attempt.rating,
      ...(attempt.remarks ? { remarks: attempt.remarks } : {}),
      ...(attempt.photoPath ? { photoPath: attempt.photoPath } : {}),
    }
  }

  const firstVersion = (
    recipe: Recipe,
    origin: VersionOrigin,
    input: NewRecipeInput,
  ): RecipeVersion => ({
    userId: recipe.userId,
    recipeId: recipe.id,
    number: FIRST_VERSION,
    createdAt: recipe.createdAt,
    updatedAt: recipe.createdAt,
    origin,
    // No `change`/`basedOn`: v1 is the original, it iterates on nothing and
    // changes nothing. No outcome either — it awaits its first cook.
    content: input.content,
    tips: input.tips,
    // Nothing was ever cooked here, so nothing was learned to warn about yet.
    warnings: [],
  })
}
