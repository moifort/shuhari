import { GraphQLError } from 'graphql'
import { match, P } from 'ts-pattern'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError } from '~/domain/shared/graphql/errors'
import { Ai } from '~/system/ai'
import { imageWithinSizeLimit, MAX_IMPORT_PHOTOS } from '~/system/ai/limits'
import type { ImportSource } from '~/system/ai/types'
import { ImportAnalysisType } from './types'

const badInput = (message: string) =>
  new GraphQLError(message, { extensions: { code: 'BAD_USER_INPUT' } })

builder.mutationField('analyzeImport', (t) =>
  t.field({
    type: ImportAnalysisType,
    description:
      'Analyze an import source (photos, a URL or raw text) into a structured recipe preview. Exactly one source must be provided. Results are cached server-side by SHA-256.',
    args: {
      photos: t.arg.stringList({ description: 'Base64 JPEGs (no data-URL prefix)' }),
      url: t.arg.string({ description: 'A recipe web page to read' }),
      text: t.arg.string({ description: 'Raw recipe text' }),
    },
    resolve: async (_root, { photos, url, text }) => {
      const source = pickSource(photos, url, text)
      let result: Awaited<ReturnType<typeof Ai.analyzeImport>>
      try {
        result = await Ai.analyzeImport(source)
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Import analysis failed'
        throw new GraphQLError(message, { extensions: { code: 'IMPORT_FAILED' } })
      }
      return match(result)
        .with('no-recipe-found', domainError)
        .with(P.not(P.string), (analysis) => analysis)
        .exhaustive()
    },
  }),
)

const pickSource = (
  photos: string[] | null | undefined,
  url: string | null | undefined,
  text: string | null | undefined,
): ImportSource => {
  const provided = [
    photos?.length ? 'photos' : null,
    url ? 'url' : null,
    text ? 'text' : null,
  ].filter(Boolean)
  if (provided.length !== 1) throw badInput('Provide exactly one of photos, url or text')
  if (photos?.length) {
    if (photos.length > MAX_IMPORT_PHOTOS)
      throw badInput(`At most ${MAX_IMPORT_PHOTOS} photos are allowed`)
    if (!photos.every((photo) => imageWithinSizeLimit(photo.length)))
      throw badInput('A photo exceeds the 10 MB size limit')
    return { kind: 'photos', photos }
  }
  if (url) return { kind: 'url', url }
  return { kind: 'text', text: text as string }
}
