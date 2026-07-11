import { builder } from '~/domain/shared/graphql/builder'

export const ProposalVarInput = builder.inputType('ProposalVarInput', {
  description: 'An edited proposed change (overrides the AI proposal before validating)',
  fields: (t) => ({
    key: t.field({ type: 'ParamKey', required: true }),
    from: t.field({ type: 'ParamValue' }),
    to: t.field({ type: 'ParamValue', required: true }),
  }),
})
