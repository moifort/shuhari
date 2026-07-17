import { createHash } from 'node:crypto'
import { DISH_CATEGORY_VALUES } from '~/domain/recipe/types'
import { ImportHash, parseImportResponse, parseProposalResponse } from '~/system/ai/primitives'
import * as repository from '~/system/ai/repository'
import type {
  ImportAnalysis,
  ImportHash as ImportHashType,
  ImportSource,
  ProposalContext,
  ProposalDraft,
} from '~/system/ai/types'
import { config } from '~/system/config/index'

const GEMINI_API_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'

type GeminiResponse = { candidates?: { content: { parts: { text?: string }[] } }[] }

type GeminiPart = { text: string } | { inline_data: { mime_type: string; data: string } }

const RECIPE_TYPE_ENUM = ['cafe', 'cocktail', 'plat', 'tmx']

const importResponseSchema = {
  type: 'object',
  properties: {
    type: {
      type: 'string',
      enum: RECIPE_TYPE_ENUM,
      description:
        "Type d'expérimentation : cafe, cocktail, plat (recette cuisinée) ou tmx (Thermomix)",
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
    params: {
      type: 'array',
      description: 'Paramètres mesurables et reproductibles, avec leur unité',
      items: {
        type: 'object',
        properties: {
          key: {
            type: 'string',
            description: 'Nom du paramètre (ex : Dose, Température), ≤60 caractères',
          },
          value: {
            type: 'string',
            description: 'Valeur avec unité (ex : 18,5 g, 92 °C), ≤120 caractères',
          },
        },
        required: ['key', 'value'],
      },
    },
    ingredients: {
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
    },
    steps: {
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
    },
  },
  required: ['type', 'category', 'title'],
  propertyOrdering: [
    'type',
    'category',
    'title',
    'subtitle',
    'sourceLabel',
    'ingredients',
    'params',
    'steps',
  ],
}

const proposalResponseSchema = {
  type: 'object',
  properties: {
    vars: {
      type: 'array',
      description: 'Changements de paramètres proposés',
      items: {
        type: 'object',
        properties: {
          key: { type: 'string', description: 'Paramètre à changer, ≤60 caractères' },
          from: {
            type: 'string',
            nullable: true,
            description: 'Valeur actuelle (null si nouveau), ≤120 caractères',
          },
          to: { type: 'string', description: 'Nouvelle valeur avec unité, ≤120 caractères' },
        },
        required: ['key', 'to'],
      },
    },
    rationale: { type: 'string', description: 'Explication du raisonnement, en français' },
    queued: {
      type: 'array',
      items: { type: 'string' },
      description: 'Autres pistes à explorer plus tard (itérations suivantes)',
    },
    recommendation: {
      type: 'string',
      enum: ['iteration', 'variation'],
      description: 'iteration = améliorer la recette ; variation = créer une déclinaison distincte',
    },
    variation: {
      type: 'object',
      nullable: true,
      properties: {
        title: { type: 'string', description: 'Nom proposé pour la variation, ≤200 caractères' },
        description: { type: 'string', description: 'En quoi elle diffère' },
      },
      required: ['title', 'description'],
    },
  },
  required: ['vars', 'rationale', 'recommendation'],
  propertyOrdering: ['vars', 'rationale', 'queued', 'recommendation', 'variation'],
}

const IMPORT_INSTRUCTIONS = `Tu es l'assistant d'un carnet d'expérimentation culinaire. À partir de la source fournie (photos, page web ou texte d'une recette), extrais une recette STRUCTURÉE et REPRODUCTIBLE.

Règles :
- Détermine le type : cafe (espresso, filtre…), cocktail, plat (recette cuisinée), tmx (recette Thermomix).
- Détermine la catégorie du plat : entree, plat, dessert, soupe, sauce ou boulangerie (pâtisserie, pain, viennoiserie). En cas de doute, choisis plat.
- ingredients : liste ORDONNÉE des composants de la recette avec leur quantité (ex : Gin → 50 ml, Beurre → 170 g, Fraise → 3 pièces). Mets TOUS les ingrédients visibles sur la source, chacun avec sa quantité et son unité. C'est la « liste de courses » de la recette. Le NOM reste court : l'ingrédient seul, jamais sa préparation (« Pommes de terre », pas « Pommes de terre épluchées et coupées en rondelles » — la préparation va dans les étapes).
- params : réglages reproductibles qui ne sont PAS des ingrédients (ex : Température → 92 °C, Mouture → fine, Ratio → 1:2, Temps d'extraction → 27 s, Four → 180 °C). N'y mets JAMAIS un ingrédient. N'invente pas de valeurs absentes ; ne garde que ce qui est réellement mesurable et reproductible (souvent vide pour un cocktail ou un plat).
- steps : étapes courtes, à l'impératif, dans l'ordre.
- Pour une recette Thermomix (type tmx) : pour chaque étape exécutée au Thermomix, renseigne tmxTime, tmxTemperature, tmxSpeed et tmxReverse tels qu'indiqués dans la recette (durée « 3 min » / « 30 s » / « 1 h 10 min » ; température « 100°C » ou « Varoma » ; vitesse « 0,5 » à « 10 », « pétrin », « mijotage » ou « turbo »). Mets null pour chaque réglage absent, et pour TOUS ces champs quand l'étape ne se fait pas au Thermomix ou que la recette n'est pas de type tmx.
- Sois concis : chaque valeur reste courte (nom d'ingrédient ≤120, quantité ≤60, paramètre clé ≤60 / valeur ≤120, étape ≤300, titre ≤200, réglage Thermomix ≤20 caractères).
- Toutes les valeurs textuelles en français. Mets null pour toute information absente.`

export namespace Ai {
  export const analyzeImport = async (source: ImportSource): Promise<ImportAnalysis> => {
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
    // Best-effort cache: a failed write only costs a re-analysis on the next hit.
    repository.save({ importHash, result, cachedAt: new Date() }).catch(() => {})
    return result
  }

  export const proposeNext = async (context: ProposalContext): Promise<ProposalDraft> => {
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
      return [{ text: `${IMPORT_INSTRUCTIONS}\n\nSource à lire : ${source.url}` }]
    }
    return [{ text: `${IMPORT_INSTRUCTIONS}\n\nTexte de la recette :\n${source.text}` }]
  }

  const oneVariableRule = (type: ProposalContext['type']) =>
    type === 'cafe' || type === 'cocktail'
      ? "RÈGLE STRICTE : pour un café ou un cocktail, ne change QU'UNE SEULE variable par itération (pour isoler cause et effet). Mets toutes les autres pistes dans queued, ordonnées pour de futures itérations."
      : 'Pour un plat ou une recette Thermomix, tu peux changer plusieurs variables cohérentes dans la même itération.'

  const proposalPrompt = (context: ProposalContext): string => {
    const params = context.currentParams.map((p) => `- ${p.key} : ${p.value}`).join('\n')
    const steps = context.currentSteps.map((s, i) => `${i + 1}. ${s}`).join('\n')
    const trials = context.trials
      .map((t) => {
        const real =
          t.realParams.map((p) => `${p.key}=${p.value}`).join(', ') || 'conformes aux cibles'
        return `- Note ${t.note}/5. Remarques : ${t.remarks || '—'}. Paramètres réels : ${real}.`
      })
      .join('\n')
    const queue = context.previousQueue.length
      ? `\n\nPistes déjà en file d'attente : ${context.previousQueue.join(' ; ')}.`
      : ''

    return `Tu es l'assistant d'un carnet d'expérimentation culinaire. Analyse les essais et propose la PROCHAINE étape.

${oneVariableRule(context.type)}

Recette actuelle (paramètres) :
${params}

Étapes :
${steps}

Essais réalisés :
${trials}${queue}

Propose soit une itération (amélioration de cette recette), soit une variation (déclinaison distincte, ex : une version blanche d'un cocktail) si les remarques suggèrent un plat différent plutôt qu'une correction. Renseigne vars (changements), rationale (pourquoi), queued (pistes suivantes), recommendation et, si variation, un titre et une description. Toutes les valeurs textuelles en français.`
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
    // 'v4' salts the cache: bumped from 'v3' (ingredient extraction) so the
    // concise-formatting prompt and the clamp/drop guard rails re-run on the next
    // import of a previously-analysed source instead of serving the old result.
    const material =
      source.kind === 'photos'
        ? `v4|${source.photos.join('|')}`
        : source.kind === 'url'
          ? `v4|url:${source.url}`
          : `v4|text:${source.text}`
    return ImportHash(createHash('sha256').update(material).digest('hex'))
  }
}
