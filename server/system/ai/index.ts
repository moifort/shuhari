import { createHash } from 'node:crypto'
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
    title: { type: 'string', description: 'Nom de la recette' },
    subtitle: { type: 'string', nullable: true, description: 'Sous-titre court (origine, style)' },
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
          key: { type: 'string', description: 'Nom du paramètre (ex : Dose, Température)' },
          value: { type: 'string', description: 'Valeur avec unité (ex : 18,5 g, 92 °C)' },
        },
        required: ['key', 'value'],
      },
    },
    steps: {
      type: 'array',
      items: { type: 'string' },
      description: 'Étapes courtes et actionnables, dans l’ordre',
    },
  },
  required: ['type', 'title'],
  propertyOrdering: ['type', 'title', 'subtitle', 'sourceLabel', 'params', 'steps'],
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
          key: { type: 'string', description: 'Paramètre à changer' },
          from: {
            type: 'string',
            nullable: true,
            description: 'Valeur actuelle (null si nouveau)',
          },
          to: { type: 'string', description: 'Nouvelle valeur avec unité' },
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
        title: { type: 'string', description: 'Nom proposé pour la variation' },
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
- params : liste ORDONNÉE de paramètres mesurables, chacun avec une valeur ET son unité (ex : Dose → 18,5 g, Température → 92 °C, Mouture → fine). N'invente pas de valeurs absentes ; ne garde que ce qui est réellement mesurable et reproductible.
- steps : étapes courtes, à l'impératif, dans l'ordre.
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
        return `- Note ${t.note}/10. Remarques : ${t.remarks || '—'}. Paramètres réels : ${real}.`
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
    const material =
      source.kind === 'photos'
        ? source.photos.join('|')
        : source.kind === 'url'
          ? `url:${source.url}`
          : `text:${source.text}`
    return ImportHash(createHash('sha256').update(material).digest('hex'))
  }
}
