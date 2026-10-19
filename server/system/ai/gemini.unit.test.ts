import { afterEach, beforeEach, describe, expect, mock, spyOn, test } from 'bun:test'
import * as Sentry from '@sentry/node'

// The real `config()` reads Nitro's runtime config, which a test process does not
// have. Every field is present, not just the key: `mock.module` replaces a module
// for the WHOLE test process, so a partial fake would blank the rest for every
// other file (see `fake-firestore.ts`).
mock.module('~/system/config', () => ({
  config: () => ({
    apiToken: undefined,
    adminToken: undefined,
    googleApiKey: 'test-gemini-key',
    premiumUserIds: [],
    appleAppId: undefined,
    appleEnvironment: undefined,
    electrolux: undefined,
  }),
}))

const { GEMINI_FAILED, callGemini } = await import('~/system/ai/gemini')

// `$fetch` is a Nitro global; the test process has none, so each test plants the
// one it needs and records what the call was made with.
type FetchCall = { url: string; headers: Record<string, string> }
const nitro = globalThis as unknown as { $fetch?: unknown }
let calls: FetchCall[]
const answerWith = (answer: () => Promise<unknown>) => {
  nitro.$fetch = mock(async (url: string, options: { headers: Record<string, string> }) => {
    calls.push({ url, headers: options.headers })
    return answer()
  })
}

const captured = spyOn(Sentry, 'captureException')

beforeEach(() => {
  calls = []
  captured.mockReset()
  captured.mockImplementation(() => 'event-id')
})

afterEach(() => {
  nitro.$fetch = undefined
})

describe('callGemini', () => {
  test('calls gemini-3.5-flash-lite with the key in a header, never in the URL', async () => {
    answerWith(async () => ({ candidates: [{ content: { parts: [{ text: '{"ok":true}' }] } }] }))

    const text = await callGemini({ contents: [] })

    expect(text).toBe('{"ok":true}')
    expect(calls).toHaveLength(1)
    expect(calls[0].url).toBe(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent',
    )
    expect(calls[0].url).not.toContain('key=')
    expect(calls[0].headers['x-goog-api-key']).toBe('test-gemini-key')
  })

  test('a failed call reaches the caller as a neutral error, the cause goes to the reporter', async () => {
    // What ofetch says when the model answers 404: the full request URL, which
    // used to carry the key as a query parameter.
    const fetchError = new Error(
      '[POST] "https://generativelanguage.googleapis.com/v1beta/models/x:generateContent?key=test-gemini-key": 404 Not Found',
    )
    answerWith(async () => {
      throw fetchError
    })

    const failure = callGemini({ contents: [] })

    await expect(failure).rejects.toThrow(GEMINI_FAILED)
    const message = await failure.catch((error: Error) => error.message)
    expect(message).not.toContain('test-gemini-key')
    expect(message).not.toContain('generativelanguage')
    expect(captured).toHaveBeenCalledTimes(1)
    expect(captured.mock.calls[0][0]).toBe(fetchError)
  })
})
