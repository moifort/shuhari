import Apollo
import ApolloAPI
import Foundation

enum PropositionAPI {
    /// Accept the proposition as an iteration. The proposition FULLY REPLACES the
    /// next version — the lists are complete, not partial. `basedOn` is echoed back
    /// so the new version records what it was built from.
    static func accept(recipeId: String, proposition: PropositionEdit) async throws {
        let tmxSteps = proposition.tmxSteps.map { GraphQLHelpers.tmxSettingsInput($0) }
        let input = ShuhariGraphQL.ProposalInput(
            basedOn: proposition.basedOn,
            changeSummary: proposition.changeSummary,
            ingredients: proposition.ingredients.map { ShuhariGraphQL.IngredientInput(name: $0.name, quantity: $0.quantity) },
            rationale: proposition.rationale,
            steps: proposition.steps,
            tmxSteps: tmxSteps
        )

        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.AcceptProposalMutation(recipeId: recipeId, proposal: input)
        )
    }
}
