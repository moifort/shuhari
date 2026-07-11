import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  Note as NoteType,
  Remarks as RemarksType,
  TrialId as TrialIdType,
} from '~/domain/trial/types'

export const TrialId = (value: unknown) => {
  const v = z.string().uuid().parse(value)
  return make<TrialIdType>()(v)
}

export const randomTrialId = () => TrialId(crypto.randomUUID())

export const Note = (value: unknown) => {
  const v = z
    .preprocess((n) => (typeof n === 'string' ? Number(n) : n), z.number().int().min(1).max(10))
    .parse(value)
  return make<NoteType>()(v)
}

export const Remarks = (value: unknown) => {
  const v = z.string().max(2000).parse(value)
  return make<RemarksType>()(v)
}
