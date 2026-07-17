import { createHash } from 'node:crypto'
import { DISH_CATEGORY_VALUES, RECIPE_TYPE_VALUES } from '~/domain/recipe/types'
import { ImportHash, parseDraftResponse, parseImportResponse } from '~/system/ai/primitives'
import * as repository from '~/system/ai/repository'
import type {
  Draft,
  DraftContext,
  ImportHash as ImportHashType,
  ImportSource,
} from '~/system/ai/types'
import { config } from '~/system/config/index'

const GEMINI_API_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'

type GeminiResponse = { candidates?: { content: { parts: { text?: string }[] } }[] }

type GeminiPart = { text: string } | { inline_data: { mime_type: string; data: string } }

const RECIPE_TYPE_ENUM = [...RECIPE_TYPE_VALUES]

// Shared ingredient/step item shapes so the import and draft schemas can't drift.
const ingredientsSchemaProperty = {
  type: 'array',
  description: 'Ingrédients de la recette avec leur quantité',
  items: {
    type: 'object',
    properties: {
      name: {
        type: 'string',
        description:
          "Nom court de l'ingrédient SEUL, sans préparation (ex : Gin, Beurre, Pommes de terre). La préparation (épluché, coupé en rondelles…) va dans les étapes, PAS dans le nom. ≤120 caractères.",
      },
      quantity: {
        type: 'string',
        description: 'Quantité avec unité (ex : 50 ml, 170 g, 3 pièces), ≤60 caractères',
      },
    },
    required: ['name', 'quantity'],
  },
}

const stepsSchemaProperty = {
  type: 'array',
  description: 'Étapes courtes et actionnables, dans l’ordre',
  items: {
    type: 'object',
    properties: {
      text: {
        type: 'string',
        description: "Texte court de l'étape, à l'impératif, ≤300 caractères",
      },
      tmxTime: {
        type: 'string',
        nullable: true,
        description: 'Durée Thermomix (ex : « 3 min », « 30 s ») ; null sinon',
      },
      tmxTemperature: {
        type: 'string',
        nullable: true,
        description: 'Température Thermomix (ex : « 100°C », « Varoma ») ; null sinon',
      },
      tmxSpeed: {
        type: 'string',
        nullable: true,
        description:
          'Vitesse Thermomix (ex : « 5 », « 3,5 », « pétrin », « mijotage », « turbo ») ; null sinon',
      },
      tmxReverse: {
        type: 'boolean',
        nullable: true,
        description: 'Sens inverse activé ; null sinon',
      },
    },
    required: ['text'],
    propertyOrdering: ['text', 'tmxTime', 'tmxTemperature', 'tmxSpeed', 'tmxReverse'],
  },
}

const importResponseSchema = {
  type: 'object',
  properties: {
    recipeFound: {
      type: 'boolean',
      description: 'true si la source contient une recette exploitable, false sinon',
    },
    type: {
      type: 'string',
      enum: RECIPE_TYPE_ENUM,
      description: "Type d'expérimentation : plat (recette cuisinée) ou tmx (Thermomix)",
    },
    category: {
      type: 'string',
      enum: DISH_CATEGORY_VALUES,
      description: 'Catégorie du plat : entree, plat, dessert, soupe, sauce ou boulangerie',
    },
    title: { type: 'string', description: 'Nom de la recette (concis, ≤200 caractères)' },
    subtitle: {
      type: 'string',
      nullable: true,
      description: 'Sous-titre court (origine, style), ≤200 caractères',
    },
    sourceLabel: {
      type: 'string',
      nullable: true,
      description: 'Source de la recette (auteur, site, livre) si identifiable',
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
    'subtitle',
    'sourceLabel',
    'ingredients',
    'steps',
  ],
}

const draftResponseSchema = {
  type: 'object',
  properties: {
    changeSummary: {
      type: 'string',
      description:
        'Résumé court de ce qui change (ex : « Bouillon 700 → 650 ml »), ≤200 caractères',
    },
    rationale: { type: 'string', description: 'Explication du raisonnement, en français' },
    ingredients: ingredientsSchemaProperty,
    steps: stepsSchemaProperty,
  },
  required: ['changeSummary', 'rationale', 'ingredients', 'steps'],
  propertyOrdering: ['changeSummary', 'rationale', 'ingredients', 'steps'],
}

const IMPORT_INSTRUCTIONS = `Tu es l'assistant d'un carnet d'expérimentation culinaire. À partir de la source fournie (photos, page web ou texte d'une recette), extrais une recette STRUCTURÉE et REPRODUCTIBLE.

Règles :
- Détermine le type : plat (recette cuisinée) ou tmx (recette Thermomix).
- Détermine la catégorie du plat : entree, plat, dessert, soupe, sauce ou boulangerie (pâtisserie, pain, viennoiserie). En cas de doute, choisis plat.
- ingredients : liste ORDONNÉE des composants de la recette avec leur quantité (ex : Gin → 50 ml, Beurre → 170 g, Fraise → 3 pièces). Mets TOUS les ingrédients visibles sur la source, chacun avec sa quantité et son unité. C'est la « liste de courses » de la recette. Le NOM reste court : l'ingrédient seul, jamais sa préparation (« Pommes de terre », pas « Pommes de terre épluchées et coupées en rondelles » — la préparation va dans les étapes).
- steps : étapes courtes, à l'impératif, dans l'ordre. Les réglages précis (température du four, durée, ratio…) restent dans le texte de l'étape.
- Pour une recette Thermomix (type tmx) : pour chaque étape exécutée au Thermomix, renseigne tmxTime, tmxTemperature, tmxSpeed et tmxReverse tels qu'indiqués dans la recette (durée « 3 min » / « 30 s » / « 1 h 10 min » ; température « 100°C » ou « Varoma » ; vitesse « 0,5 » à « 10 », « pétrin », « mijotage » ou « turbo »). Mets null pour chaque réglage absent, et pour TOUS ces champs quand l'étape ne se fait pas au Thermomix ou que la recette n'est pas de type tmx.
- Sois concis : chaque valeur reste courte (nom d'ingrédient ≤120, quantité ≤60, étape ≤300, titre ≤200, réglage Thermomix ≤20 caractères).
- Si la source ne contient aucune recette exploitable (image illisible ou sans recette, page ou texte hors sujet), mets recipeFound à false et laisse tous les autres champs vides ou null. Sinon mets recipeFound à true.
- Toutes les valeurs textuelles en français. Mets null pour toute information absente.`

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

  export const draftNext = async (context: DraftContext): Promise<Draft> => {
    const text = await callGemini({
      contents: [{ parts: [{ text: draftPrompt(context) }] }],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: draftResponseSchema,
      },
    })
    if (!text) throw new Error('Gemini did not return a structured draft')
    return parseDraftResponse(text)
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
      return [{ text: `${IMPORT_INSTRUCTIONS}\n\nSource à lire : ${source.url}` }]
    }
    return [{ text: `${IMPORT_INSTRUCTIONS}\n\nTexte de la recette :\n${source.text}` }]
  }

  // Cuisine-scoped iteration rule (plat + tmx). Café/cocktail will get their own
  // rules later — no speculative abstraction here.
  const cuisineIterationRule = (_type: DraftContext['type']) =>
    'Pour un plat ou une recette Thermomix, tu peux ajuster plusieurs éléments cohérents à la fois. Renvoie la liste COMPLÈTE des ingrédients et des étapes de la prochaine version (pas seulement ce qui change), plus un résumé court des changements.'

  const formatTmx = (tmx: NonNullable<DraftContext['currentTmxSteps'][number]>): string => {
    const parts = [
      tmx.time && `durée ${tmx.time}`,
      tmx.temperature && `température ${tmx.temperature}`,
      tmx.speed && `vitesse ${tmx.speed}`,
      tmx.reverse && 'sens inverse',
    ].filter(Boolean)
    return parts.length ? ` [Thermomix : ${parts.join(', ')}]` : ''
  }

  const draftPrompt = (context: DraftContext): string => {
    const ingredients =
      context.currentIngredients.map((i) => `- ${i.name} : ${i.quantity}`).join('\n') || '—'
    const steps =
      context.currentSteps
        .map((s, i) => {
          const tmx = context.currentTmxSteps[i]
          return `${i + 1}. ${s}${tmx ? formatTmx(tmx) : ''}`
        })
        .join('\n') || '—'
    const trials =
      context.trials
        .map((t) => `- Note ${t.note}/5. Remarques : ${t.remarks || '—'}.`)
        .join('\n') || '—'

    return `Tu es l'assistant d'un carnet d'expérimentation culinaire. Analyse les essais et propose la PROCHAINE version de la recette.

${cuisineIterationRule(context.type)}

Ingrédients actuels :
${ingredients}

Étapes actuelles :
${steps}

Essais réalisés :
${trials}

Propose une itération : une amélioration de cette recette. Renseigne changeSummary (résumé court de ce qui change), rationale (pourquoi), ingredients et steps (la liste COMPLÈTE de la prochaine version). Toutes les valeurs textuelles en français.`
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
    // 'v6' salts the cache: bumped from 'v5' because the import prompt/schema
    // gained the explicit recipeFound signal, so previously-analysed sources —
    // including empty ones — re-run instead of serving a stale result.
    const material =
      source.kind === 'photos'
        ? `v6|${source.photos.join('|')}`
        : source.kind === 'url'
          ? `v6|url:${source.url}`
          : `v6|text:${source.text}`
    return ImportHash(createHash('sha256').update(material).digest('hex'))
  }
}
