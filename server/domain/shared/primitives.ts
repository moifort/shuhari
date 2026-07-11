import { make } from 'ts-brand'
import { z } from 'zod'
import type { Count as CountType, UserId as UserIdType } from '~/domain/shared/types'

export const UserId = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<UserIdType>()(v)
}

export const Count = (value: number) => make<CountType>()(value)
