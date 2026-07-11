import { make } from 'ts-brand'
import { z } from 'zod'
import type { ChangelogVersion as ChangelogVersionType } from '~/domain/changelog/types'

const versionSchema = z
  .string()
  .min(1)
  .refine((v) => v === 'Unreleased' || /^\d{4}\.\d{2}\.\d{2}$/.test(v), {
    message: 'Expected Unreleased or YYYY.MM.DD',
  })

export const ChangelogVersion = (value: unknown) => {
  const v = versionSchema.parse(value)
  return make<ChangelogVersionType>()(v)
}
