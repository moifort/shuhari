import { EntitlementCommand } from '~/domain/entitlement/command'
import { QuotaCommand } from '~/domain/quota/command'
import { RecipeCommand } from '~/domain/recipe/command'
import type { UserId } from '~/domain/shared/types'
import { auth } from '~/system/firebase'

export namespace AccountUseCase {
  /// Erase a cook and everything the app holds on them. Irreversible, and immediate:
  /// there is no grace period to reason about and no scheduled job to watch.
  ///
  /// Each domain forgets its own documents — none of them knows about the others —
  /// and the account itself goes last. The order is the point: an account deleted
  /// before its data would leave documents keyed to a user nobody can authenticate
  /// as, unreachable and unclaimable. The reverse merely leaves an empty account,
  /// which the next attempt finishes off.
  ///
  /// What this cannot do is end a subscription. Only the App Store can, at the cook's
  /// own request — the app says so before it deletes anything.
  export const remove = async (userId: UserId): Promise<void> => {
    await RecipeCommand.forget(userId)
    await QuotaCommand.forget(userId)
    await EntitlementCommand.forget(userId)
    await auth().deleteUser(userId)
  }
}
