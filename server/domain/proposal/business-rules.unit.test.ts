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
  test('coffee and cocktails get one variable', () => {
    expect(variableBudget('cafe')).toBe(1)
    expect(variableBudget('cocktail')).toBe(1)
  })
  test('dishes and thermomix get many', () => {
    expect(variableBudget('plat')).toBe('many')
    expect(variableBudget('tmx')).toBe('many')
  })
})

describe('respectsVariableBudget', () => {
  test('cafe requires exactly one variable', () => {
    expect(respectsVariableBudget('cafe', [pvar('Dose', '18 g', '19 g')])).toBe(true)
    expect(respectsVariableBudget('cafe', [])).toBe(false)
    expect(
      respectsVariableBudget('cafe', [pvar('Dose', '18 g', '19 g'), pvar('Temp', '93', '92')]),
    ).toBe(false)
  })
  test('plat accepts one or more variables but not zero', () => {
    expect(respectsVariableBudget('plat', [pvar('Riz', '300 g', '320 g')])).toBe(true)
    expect(
      respectsVariableBudget('plat', [pvar('Riz', '300 g', '320 g'), pvar('Sel', '5 g', '6 g')]),
    ).toBe(true)
    expect(respectsVariableBudget('plat', [])).toBe(false)
  })
})

describe('overflowToQueue', () => {
  test('coffee keeps the first variable and queues the rest', () => {
    const vars = [pvar('Température', '93 °C', '92 °C'), pvar('Dose', '18 g', '18,5 g')]
    const result = overflowToQueue('cafe', vars)
    expect(result.vars).toEqual([pvar('Température', '93 °C', '92 °C')])
    expect(result.queued).toEqual(['Dose : 18 g → 18,5 g'])
  })
  test('preserves an existing queue and appends overflow', () => {
    const vars = [pvar('A', '1', '2'), pvar('B', null, '3')]
    const result = overflowToQueue('cocktail', vars, ['ancien'])
    expect(result.queued).toEqual(['ancien', 'B : — → 3'])
  })
  test('dishes keep every variable and their queue untouched', () => {
    const vars = [pvar('A', '1', '2'), pvar('B', '3', '4')]
    const result = overflowToQueue('plat', vars, ['garder'])
    expect(result.vars).toEqual(vars)
    expect(result.queued).toEqual(['garder'])
  })
  test('a single variable is passed through unchanged', () => {
    const vars = [pvar('A', '1', '2')]
    expect(overflowToQueue('cafe', vars).vars).toEqual(vars)
  })
})
