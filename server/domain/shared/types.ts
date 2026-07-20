import type { Brand } from 'ts-brand'

export type UserId = Brand<string, 'UserId'>
export type Count = Brand<number, 'Count'>

// What a cook is entitled to. `free` is the default for everyone; `premium` is
// the paid subscription — unlimited AI, plus the URL import. Shared vocabulary:
// the `subscription` domain grants it, the `quota` domain meters against it.
export const PLAN_VALUES = ['free', 'premium'] as const
export type Plan = (typeof PLAN_VALUES)[number]
