import type { Attempt } from '~/domain/recipe/command'
import type { VersionContent } from '~/domain/recipe/content/types'
import type { VersionNumber } from '~/domain/recipe/types'

// An ephemeral next-version proposal, already validated into branded domain
// shapes — either freshly branded from the AI (`fromAttempt`) or the user's inline
// edits from iOS. Never persisted: it is generated, returned, and handed straight
// back on accept, which appends it as version n+1 based on `basedOn`.
export type Proposal = {
  basedOn: VersionNumber
  changeSummary: string
  rationale: string
  content: VersionContent
}

// The client-supplied proposal to accept: everything that becomes version n+1,
// including the `basedOn` it iterates on (threaded back so accept never rescans
// the lineage to recover it) and the attempt that asked for it — the cook whose
// remarks the AI answered, recorded on the version it gives birth to.
export type AcceptedProposal = Proposal & { attempt: Attempt }
