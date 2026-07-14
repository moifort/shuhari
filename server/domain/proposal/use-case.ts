import { overflowToQueue, respectsVariableBudget } from '~/domain/proposal/business-rules'
import { ProposalCommand } from '~/domain/proposal/command'
import { ProposalQuery } from '~/domain/proposal/query'
import type { Proposal, ProposalVar } from '~/domain/proposal/types'
import { applyProposalToParams } from '~/domain/recipe/business-rules'
import { RecipeCommand } from '~/domain/recipe/command'
import { ParamKey, ParamValue, RecipeTitle } from '~/domain/recipe/primitives'
import { RecipeQuery } from '~/domain/recipe/query'
import type { Param, RecipeId, VersionNumber } from '~/domain/recipe/types'
import type { UserId } from '~/domain/shared/types'
import { TrialQuery } from '~/domain/trial/query'
import { Ai } from '~/system/ai'

const toProposalVar = (raw: { key: string; from: string | null; to: string }) => ({
  key: ParamKey(raw.key),
  from: raw.from === null ? null : ParamValue(raw.from),
  to: ParamValue(raw.to),
})

const describeChange = (vars: ProposalVar[]) =>
  vars.map((v) => `${v.key} ${v.from ?? '∅'} → ${v.to}`).join(' · ')

export namespace ProposalUseCase {
  // Ask the AI for the next step after a trial. Reads the tested version and its
  // trials, drafts a proposal, enforces the one-variable rule for cafe/cocktail,
  // and persists it as the single active proposal for that version.
  export const proposeFromTrial = async (userId: UserId, recipeId: RecipeId) => {
    const recipe = await RecipeQuery.byId(userId, recipeId)
    if (recipe === 'not-found') return 'not-found'
    const version = await RecipeQuery.versionBy(recipeId, recipe.currentVersion)
    if (version === 'not-found') return 'not-found'
    const trials = await TrialQuery.byVersion(userId, recipeId, recipe.currentVersion)

    const draft = await Ai.proposeNext({
      type: recipe.type,
      currentParams: version.params.map((p) => ({ key: p.key, value: p.value })),
      currentSteps: version.steps.map((s) => s as string),
      trials: trials.map((t) => ({
        note: t.note,
        remarks: t.remarks,
        realParams: t.realParams.map((p) => ({ key: p.key, value: p.value })),
      })),
      previousQueue: [],
    })

    const { vars, queued } = overflowToQueue(
      recipe.type,
      draft.vars.map(toProposalVar),
      draft.queued,
    )

    const proposal: Proposal = {
      userId,
      recipeId,
      versionNumber: recipe.currentVersion,
      createdAt: new Date(),
      vars,
      rationale: draft.rationale,
      queued,
      recommendation: draft.recommendation,
      ...(draft.variation
        ? {
            variation: {
              title: RecipeTitle(draft.variation.title),
              description: draft.variation.description,
            },
          }
        : {}),
    }
    return ProposalCommand.propose(proposal)
  }

  // Accept a proposal as an iteration: append version n+1 (target params merged
  // with the proposed changes) and mark it "to test". editedVars lets the user
  // tweak the changes before validating — revalidated against the budget.
  export const acceptAsIteration = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumber,
    editedVars?: ProposalVar[],
  ) => {
    const recipe = await RecipeQuery.byId(userId, recipeId)
    if (recipe === 'not-found') return 'not-found'
    const proposal = await ProposalQuery.byRef(recipeId, versionNumber)
    if (!proposal) return 'no-proposal'
    const vars = editedVars ?? proposal.vars
    if (!respectsVariableBudget(recipe.type, vars)) return 'budget-exceeded'
    const base = await RecipeQuery.versionBy(recipeId, versionNumber)
    if (base === 'not-found') return 'not-found'

    const params: Param[] = applyProposalToParams(
      base.params,
      vars.map((v) => ({ key: v.key, value: v.to })),
    )
    const result = await RecipeCommand.addVersion(userId, recipeId, {
      change: describeChange(vars),
      changedKeys: vars.map((v) => v.key),
      ...(proposal.rationale ? { why: proposal.rationale } : {}),
      params,
      steps: base.steps,
      ...(base.ingredients ? { ingredients: base.ingredients } : {}),
      ...(base.tmxSteps ? { tmxSteps: base.tmxSteps } : {}),
    })
    if (result !== 'not-found') await ProposalCommand.discard(recipeId, versionNumber)
    return result
  }

  // Accept a proposal as a variation: a brand-new recipe derived from this one,
  // carrying the proposed changes as its v1.
  export const acceptAsVariation = async (
    userId: UserId,
    recipeId: RecipeId,
    versionNumber: VersionNumber,
    editedVars?: ProposalVar[],
  ) => {
    const recipe = await RecipeQuery.byId(userId, recipeId)
    if (recipe === 'not-found') return 'not-found'
    const proposal = await ProposalQuery.byRef(recipeId, versionNumber)
    if (!proposal) return 'no-proposal'
    const vars = editedVars ?? proposal.vars
    const base = await RecipeQuery.versionBy(recipeId, versionNumber)
    if (base === 'not-found') return 'not-found'

    const title = proposal.variation?.title ?? recipe.title
    const params: Param[] = applyProposalToParams(
      base.params,
      vars.map((v) => ({ key: v.key, value: v.to })),
    )
    const result = await RecipeCommand.deriveVariation(
      userId,
      recipeId,
      {
        type: recipe.type,
        title,
        ...(recipe.subtitle ? { subtitle: recipe.subtitle } : {}),
        params,
        steps: base.steps,
        ...(base.ingredients ? { ingredients: base.ingredients } : {}),
        ...(base.tmxSteps ? { tmxSteps: base.tmxSteps } : {}),
      },
      describeChange(vars),
    )
    if (result !== 'not-found') await ProposalCommand.discard(recipeId, versionNumber)
    return result
  }

  export const refuse = async (recipeId: RecipeId, versionNumber: VersionNumber) =>
    ProposalCommand.discard(recipeId, versionNumber)
}
