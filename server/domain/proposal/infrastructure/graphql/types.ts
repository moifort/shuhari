import { DishCategoryEnum, RecipeTypeEnum } from '~/domain/recipe/infrastructure/graphql/enums'
import { VersionContentUnion } from '~/domain/recipe/infrastructure/graphql/types'
import type { Tip } from '~/domain/recipe/types'
import { builder } from '~/domain/shared/graphql/builder'
import type { ImportAnalysis, ImportStep, ImportThermomixSettings } from '~/system/ai/types'
import type { Proposal } from '../../types'

export const ProposalType = builder.objectRef<Proposal>('Proposal').implement({
  description:
    'The AI’s suggestion for your next attempt, e.g. `"Less sugar, longer resting time"`. After ' +
    'an attempt, the AI reads your rating and remarks and proposes a tweaked version. It is ' +
    'just a proposal shown on screen — nothing is saved until you accept it (see ' +
    'acceptProposal).',
  fields: (t) => ({
    basedOn: t.expose('basedOn', {
      type: 'VersionNumber',
      description:
        'The version this proposal iterates on (the one you just cooked), e.g. `2`. Sent straight ' +
        'back on accept so the new version records what it was based on.',
    }),
    changeSummary: t.exposeString('changeSummary', {
      description:
        'A one-line summary of what it changes, e.g. `"Less sugar, longer resting time"`',
    }),
    rationale: t.exposeString('rationale', {
      description:
        'The AI’s reasoning — why it thinks this change will help, based on your last remarks, ' +
        'e.g. `"You noted it was too sweet, so cutting the sugar should balance it"`',
    }),
    content: t.field({
      type: VersionContentUnion,
      description:
        'The complete body of the suggested version (not just what changed) — a `DishContent` or ' +
        'a `ThermomixContent` depending on the recipe type',
      resolve: (d) => d.content,
    }),
    tips: t.field({
      type: ['Tip'],
      description:
        'The complete tips list of the suggested version — the current tips carried over, any ' +
        'advice found in your remarks folded in, e.g. `["Serve over rice"]`',
      resolve: (d) => d.tips,
    }),
  }),
})

// The tips-only proposal: the complete merged list the current version's tips
// would be replaced with. Ephemeral like ProposalType — accepting it goes through
// the updateTips mutation, which touches no other part of the version.
export const TipsProposalType = builder.objectRef<{ tips: Tip[] }>('TipsProposal').implement({
  description:
    'The AI’s reworded, merged tips list for one version — what you asked to add, folded into ' +
    'the tips it already had. Just a proposal shown on screen: nothing is saved until you send ' +
    'it back through updateTips.',
  fields: (t) => ({
    tips: t.field({
      type: ['Tip'],
      description:
        'The complete new tips list, e.g. `["Serve over rice", "Freezes well"]` — every current ' +
        'tip kept, the requested advice reworded and deduplicated',
      resolve: (p) => p.tips,
    }),
  }),
})

// Raw ingredient from the import analysis — plain strings, shown in the editable
// preview before the user confirms (values are validated into branded types on create).
type ImportIngredient = { name: string; quantity: string }

const ImportIngredientType = builder.objectRef<ImportIngredient>('ImportIngredient').implement({
  description: 'A recipe ingredient extracted by the AI (unvalidated preview)',
  fields: (t) => ({
    name: t.exposeString('name'),
    quantity: t.exposeString('quantity'),
  }),
})

const ImportThermomixSettingsType = builder
  .objectRef<ImportThermomixSettings>('ImportThermomixSettings')
  .implement({
    description: 'Thermomix settings for one step extracted by the AI (unvalidated preview)',
    fields: (t) => ({
      time: t.exposeString('time', { nullable: true }),
      temperature: t.exposeString('temperature', { nullable: true }),
      speed: t.exposeString('speed', { nullable: true }),
      reverse: t.exposeBoolean('reverse', { nullable: true }),
    }),
  })

const ImportStepType = builder.objectRef<ImportStep>('ImportStep').implement({
  description:
    'A recipe step extracted by the AI (unvalidated preview): its text plus the Thermomix ' +
    'settings that go with it (every field `null` = a plain step).',
  fields: (t) => ({
    text: t.exposeString('text'),
    settings: t.field({
      type: ImportThermomixSettingsType,
      description: 'The step’s Thermomix settings (every field `null` = a plain step)',
      resolve: (s) => s.settings,
    }),
  }),
})

export const ImportAnalysisType = builder.objectRef<ImportAnalysis>('ImportAnalysis').implement({
  description: 'Structured recipe extracted from an import source (editable preview)',
  fields: (t) => ({
    type: t.expose('type', { type: RecipeTypeEnum }),
    category: t.expose('category', {
      type: DishCategoryEnum,
      description: 'The dish category detected by the AI',
    }),
    title: t.exposeString('title'),
    sourceLabel: t.exposeString('sourceLabel', { nullable: true }),
    ingredients: t.field({ type: [ImportIngredientType], resolve: (a) => a.ingredients }),
    steps: t.field({
      type: [ImportStepType],
      description: 'The extracted steps, each carrying its own Thermomix settings',
      resolve: (a) => a.steps,
    }),
    tips: t.exposeStringList('tips', {
      description:
        'The cooking tips found in the source (unvalidated preview) — empty list when it ' +
        'carries none',
    }),
  }),
})
