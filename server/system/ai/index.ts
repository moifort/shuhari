import { createHash } from 'node:crypto'
import { DISH_CATEGORY_VALUES, RECIPE_TYPE_VALUES } from '~/domain/recipe/types'
import { ImportHash, parseImportResponse, parseProposalResponse } from '~/system/ai/primitives'
import * as repository from '~/system/ai/repository'
import type {
  ImportHash as ImportHashType,
  ImportSource,
  Proposal,
  ProposalContext,
} from '~/system/ai/types'
import { config } from '~/system/config/index'

const GEMINI_API_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'

type GeminiResponse = { candidates?: { content: { parts: { text?: string }[] } }[] }

type GeminiPart = { text: string } | { inline_data: { mime_type: string; data: string } }

const RECIPE_TYPE_ENUM = [...RECIPE_TYPE_VALUES]

// Shared ingredient/step item shapes so the import and proposal schemas can't drift.
const ingredientsSchemaProperty = {
  type: 'array',
  description: 'Recipe ingredients with their quantity, written in French',
  items: {
    type: 'object',
    properties: {
      name: {
        type: 'string',
        description:
          'Short name of the ingredient in French (e.g. "Gin", "Beurre", "Pommes de terre"). Transient preparation (peeled, sliced…) belongs in the steps, NOT in the name. But an intrinsic variety, type or grade (a potato cultivar, a flour type, a cocoa percentage) belongs in the name, in parentheses: "Pommes de terre (Marbella)", "Farine (T45)", "Chocolat noir (70 %)". ≤120 characters.',
      },
      quantity: {
        type: 'string',
        description:
          'Quantity with its unit, in French (e.g. "50 ml", "170 g", "3 pièces"), ≤60 characters',
      },
    },
    required: ['name', 'quantity'],
  },
}

// Nested Thermomix settings for one step. Every field is null on a step that is
// not performed on the Thermomix (or on a non-Thermomix recipe).
const thermomixSettingsSchemaProperty = {
  type: 'object',
  nullable: true,
  description: 'Thermomix settings for this step; null (or every field null) when it has none',
  properties: {
    time: {
      type: 'string',
      nullable: true,
      description: 'Thermomix time (e.g. "3 min", "30 s"); null when the step has none',
    },
    temperature: {
      type: 'string',
      nullable: true,
      description: 'Thermomix temperature (e.g. "100°C", "Varoma"); null when the step has none',
    },
    speed: {
      type: 'string',
      nullable: true,
      description:
        'Thermomix speed (e.g. "5", "3,5", "pétrin", "mijotage", "turbo"); null when the step has none',
    },
    reverse: {
      type: 'boolean',
      nullable: true,
      description: 'Reverse rotation enabled; null when the step has none',
    },
  },
  propertyOrdering: ['time', 'temperature', 'speed', 'reverse'],
}

const stepsSchemaProperty = {
  type: 'array',
  description: 'Short, actionable steps in order, written in French',
  items: {
    type: 'object',
    properties: {
      text: {
        type: 'string',
        description: 'Short step text, in French, imperative mood, ≤300 characters',
      },
      // Always return the step object; its settings are null on a step that is not
      // performed on the Thermomix (never skip or drop the step itself).
      settings: thermomixSettingsSchemaProperty,
    },
    required: ['text'],
    propertyOrdering: ['text', 'settings'],
  },
}

const importResponseSchema = {
  type: 'object',
  properties: {
    recipeFound: {
      type: 'boolean',
      description: 'true if the source contains a usable recipe, false otherwise',
    },
    type: {
      type: 'string',
      enum: RECIPE_TYPE_ENUM,
      description: 'Experiment type: dish (cooked recipe) or thermomix (Thermomix)',
    },
    category: {
      type: 'string',
      enum: DISH_CATEGORY_VALUES,
      description: 'Dish category: starter, main, dessert, soup, sauce, baking or drink',
    },
    title: {
      type: 'string',
      description: 'Recipe name, in French (concise, ≤200 characters)',
    },
    sourceLabel: {
      type: 'string',
      nullable: true,
      description: 'Recipe source (author, website, book) if identifiable',
    },
    ingredients: ingredientsSchemaProperty,
    steps: stepsSchemaProperty,
  },
  required: ['recipeFound', 'type', 'category', 'title'],
  propertyOrdering: [
    'recipeFound',
    'type',
    'category',
    'title',
    'sourceLabel',
    'ingredients',
    'steps',
  ],
}

const proposalResponseSchema = {
  type: 'object',
  properties: {
    changeSummary: {
      type: 'string',
      description:
        'Short summary of what changes, written in French. One change = "label old → new unit", where → is the arrow character U+2192 — ALWAYS that character between the old and the new value, never a comma, a dash, a slash or quotes. Replacing one thing by another is written the same way (e.g. "Citrons jaunes 2-3 pièces → Pomelo 1 pièce"). Several changes are joined by ", " (e.g. "Bouillon 50 → 40 cl, cuisson 3 h 30 → 4 h"). ≤200 characters',
    },
    rationale: { type: 'string', description: 'Explanation of the reasoning, written in French' },
    ingredients: ingredientsSchemaProperty,
    steps: stepsSchemaProperty,
  },
  required: ['changeSummary', 'rationale', 'ingredients', 'steps'],
  propertyOrdering: ['changeSummary', 'rationale', 'ingredients', 'steps'],
}

const IMPORT_INSTRUCTIONS = `You are the assistant of a culinary experimentation notebook. From the provided source (photos, web page or recipe text), extract a STRUCTURED and REPRODUCIBLE recipe.

Rules:
- MANDATORY: write every generated value — title, ingredient names and quantities, step text — in French. The reader is a French speaker; never answer in English.
- Determine the type: dish (cooked recipe) or thermomix (Thermomix recipe).
- Determine the dish category: starter, main, dessert, soup, sauce, baking (pastry, bread, viennoiserie) or drink (cocktail, smoothie, hot or cold beverage). When in doubt, pick main.
- ingredients: the ORDERED list of the recipe's components with their quantity (e.g. Gin → 50 ml, Beurre → 170 g, Fraise → 3 pièces). Include EVERY ingredient visible in the source, each with its quantity and unit. This is the recipe's "shopping list". The NAME stays short: the ingredient alone, never its transient preparation ("Pommes de terre", not "Pommes de terre épluchées et coupées en rondelles" — the preparation belongs in the steps). An intrinsic variety, type or grade stays in the name, in parentheses ("Pommes de terre (Marbella)", "Farine (T45)").
- steps: short steps, imperative mood, in order. Precise settings (oven temperature, duration, ratio…) stay in the step text.
- For a Thermomix recipe (type thermomix): for every step performed on the Thermomix, fill the nested settings object (time, temperature, speed, reverse) exactly as stated in the recipe (time "3 min" / "30 s" / "1 h 10 min"; temperature "100°C" or "Varoma"; speed "0,5" to "10", "pétrin", "mijotage" or "turbo"). ALWAYS return every step as an object: use null for every missing setting, and set settings to null (or leave its fields null) when the step is not done on the Thermomix or when the recipe is not of type thermomix — never omit or merge a step because it carries no setting.
- Be concise: every value stays short (ingredient name ≤120, quantity ≤60, step ≤300, title ≤200, Thermomix setting ≤20 characters).
- If the source contains no usable recipe (unreadable image or one without a recipe, off-topic page or text), set recipeFound to false and leave every other field empty or null. Otherwise set recipeFound to true.
- Use null for any missing information.

Reminder: all text values you produce must be written in French.`

export namespace Ai {
  export const analyzeImport = async (source: ImportSource) => {
    const importHash = hashSource(source)
    const cached = await repository.findBy(importHash)
    if (cached) return cached.result

    const parts = importParts(source)
    const body: Record<string, unknown> = {
      contents: [{ parts }],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: importResponseSchema,
      },
    }
    // A URL source needs web access to read the page.
    if (source.kind === 'url') body.tools = [{ google_search: {} }]

    const text = await callGemini(body)
    if (!text) throw new Error('Gemini did not return a structured recipe')
    const result = parseImportResponse(text)
    // The cache stores only real analyses; a "no recipe" outcome must re-scan on
    // the next attempt rather than serve a memoized miss.
    if (result === 'no-recipe-found') return result
    // Best-effort cache: a failed write only costs a re-analysis on the next hit.
    repository.save({ importHash, result, cachedAt: new Date() }).catch(() => {})
    return result
  }

  export const proposeNext = async (context: ProposalContext): Promise<Proposal> => {
    const text = await callGemini({
      contents: [{ parts: [{ text: proposalPrompt(context) }] }],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: proposalResponseSchema,
      },
    })
    if (!text) throw new Error('Gemini did not return a structured proposal')
    return parseProposalResponse(text)
  }

  const importParts = (source: ImportSource): GeminiPart[] => {
    if (source.kind === 'photos') {
      return [
        { text: IMPORT_INSTRUCTIONS },
        ...source.photos.map(
          (data): GeminiPart => ({ inline_data: { mime_type: 'image/jpeg', data } }),
        ),
      ]
    }
    if (source.kind === 'url') {
      return [{ text: `${IMPORT_INSTRUCTIONS}\n\nSource to read: ${source.url}` }]
    }
    return [{ text: `${IMPORT_INSTRUCTIONS}\n\nRecipe text:\n${source.text}` }]
  }

  // Cuisine-scoped iteration rule (dish + thermomix). Coffee and cocktail will get
  // their own rules later — no speculative abstraction here.
  const cuisineIterationRule = (_type: ProposalContext['type']) =>
    'For a dish or a Thermomix recipe, you may adjust several coherent elements at once. Return the COMPLETE ingredient and step list of the next version (not only what changes), plus a short summary of the changes. When the remarks ask for a precise adjustment (a new cooking time, temperature, speed or quantity), apply that exact value in the right structured field — a Thermomix time/temperature/speed in the step settings, a duration in the dish step text, a quantity on the ingredient — and record every change in changeSummary as "old → new", with the arrow character U+2192 between the two, whether the change is a new value or one ingredient replacing another.'

  const formatThermomix = (
    settings: ProposalContext['currentSteps'][number]['settings'],
  ): string => {
    const parts = [
      settings.time && `time ${settings.time}`,
      settings.temperature && `temperature ${settings.temperature}`,
      settings.speed && `speed ${settings.speed}`,
      settings.reverse && 'reverse rotation',
    ].filter(Boolean)
    return parts.length ? ` [Thermomix: ${parts.join(', ')}]` : ''
  }

  const proposalPrompt = (context: ProposalContext): string => {
    const ingredients =
      context.currentIngredients.map((i) => `- ${i.name} : ${i.quantity}`).join('\n') || '—'
    const steps =
      context.currentSteps
        // Each step carries its own settings — an empty settings object is a plain step.
        .map((s, i) => `${i + 1}. ${s.text}${formatThermomix(s.settings)}`)
        .join('\n') || '—'
    // The proposal answers either the cooks that were run, or — when the cook asked
    // for one outright — the improvement they described.
    const request = context.improvement
      ? `Improvement requested by the cook:\n${context.improvement}`
      : `Attempts made:\n${
          context.attempts
            .map((t) => `- Note ${t.rating}/5. Remarks: ${t.remarks || '—'}.`)
            .join('\n') || '—'
        }`

    return `You are the assistant of a culinary experimentation notebook. Analyse what is asked below and propose the NEXT version of the recipe.

MANDATORY: write every generated value — change summary, rationale, ingredient names and quantities, step text — in French. The reader is a French speaker; never answer in English.

${cuisineIterationRule(context.type)}

Current ingredients:
${ingredients}

Current steps:
${steps}

${request}

Propose an iteration: an improvement of this recipe. Fill changeSummary (a short summary of what changes), rationale (why), ingredients and steps (the COMPLETE list of the next version).

Reminder: all text values you produce must be written in French.`
  }

  const callGemini = async (body: Record<string, unknown>): Promise<string | undefined> => {
    const { googleApiKey } = config()
    const response = await $fetch<GeminiResponse>(`${GEMINI_API_URL}?key=${googleApiKey}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body,
    })
    return response.candidates?.[0]?.content?.parts?.find((p) => p.text)?.text
  }

  const hashSource = (source: ImportSource): ImportHashType => {
    // 'v8' salts the cache: bumped from 'v7' because the import step schema moved
    // from flat tmx* fields to a nested settings object — so previously-analysed
    // sources re-run instead of serving a stale result.
    const material =
      source.kind === 'photos'
        ? `v8|${source.photos.join('|')}`
        : source.kind === 'url'
          ? `v8|url:${source.url}`
          : `v8|text:${source.text}`
    return ImportHash(createHash('sha256').update(material).digest('hex'))
  }
}
