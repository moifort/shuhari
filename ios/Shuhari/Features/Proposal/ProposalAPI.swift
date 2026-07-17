import Apollo
import ApolloAPI
import Foundation

enum ProposalAPI {
    /// Accept a proposal as an iteration. When `editedDraft` is non-nil it FULLY
    /// REPLACES the AI draft — the lists must be complete.
    static func accept(
        recipeId: String,
        versionNumber: Int,
        editedDraft: ProposalDraft?
    ) async throws {
        let draft: GraphQLNullable<ShuhariGraphQL.ProposalDraftInput> = editedDraft.map { draft in
            let tmxSteps: GraphQLNullable<[ShuhariGraphQL.TmxSettingsInput?]> = draft.tmxSteps.isEmpty
                ? .none
                : .some(draft.tmxSteps.map { settings in
                    settings.map {
                        ShuhariGraphQL.TmxSettingsInput(
                            reverse: $0.reverse ? .some(true) : .none,
                            speed: GraphQLHelpers.graphQLNullable($0.speed),
                            temperature: GraphQLHelpers.graphQLNullable($0.temperature),
                            time: GraphQLHelpers.graphQLNullable($0.time)
                        )
                    }
                })
            return .some(ShuhariGraphQL.ProposalDraftInput(
                ingredients: draft.ingredients.map { ShuhariGraphQL.IngredientInput(name: $0.name, quantity: $0.quantity) },
                steps: draft.steps,
                tmxSteps: tmxSteps
            ))
        } ?? .none

        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.AcceptProposalMutation(
                recipeId: recipeId,
                versionNumber: versionNumber,
                editedDraft: draft
            )
        )
    }

    static func refuse(recipeId: String, versionNumber: Int) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.RefuseProposalMutation(recipeId: recipeId, versionNumber: versionNumber)
        )
    }
}
