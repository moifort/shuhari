import { describe, expect, test } from 'bun:test'
import {
  overflowToQueue,
  respectsVariableBudget,
  variableBudget,
} from '~/domain/proposal/business-rules'
import type { ProposalVar } from '~/domain/proposal/types'
import type { ParamKey, ParamValue } from '~/domain/recipe/types'

const pvar = (key: string, from: string | null, to: string): ProposalVar => ({
  key: key as ParamKey,
  from: from as ParamValue | null,
  to: to as ParamValue,
})

describe('variableBudget', () => {
  test('dishes and thermomix get many', () => {
    expect(variableBudget('plat')).toBe('many')
    expect(variableBudget('tmx')).toBe('many')
  })
})

describe('respectsVariableBudget', () => {
  test('accepts one or more variables but not zero', () => {
    expect(respectsVariableBudget('plat', [pvar('Riz', '300 g', '320 g')])).toBe(true)
    expect(
      respectsVariableBudget('tmx', [pvar('Riz', '300 g', '320 g'), pvar('Sel', '5 g', '6 g')]),
    ).toBe(true)
    expect(respectsVariableBudget('plat', [])).toBe(false)
  })
})

describe('overflowToQueue', () => {
  test('keeps every variable and the queue untouched', () => {
    const vars = [pvar('A', '1', '2'), pvar('B', '3', '4')]
    const result = overflowToQueue('plat', vars, ['garder'])
    expect(result.vars).toEqual(vars)
    expect(result.queued).toEqual(['garder'])
  })
  test('defaults to an empty queue', () => {
    const vars = [pvar('A', '1', '2')]
    expect(overflowToQueue('tmx', vars)).toEqual({ vars, queued: [] })
  })
})
