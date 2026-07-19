import Apollo
import ApolloAPI
import Foundation

enum ProposalAPI {
    /// Accept the proposal as an iteration. The proposal FULLY REPLACES the
    /// next version — the lists are complete, not partial. `basedOn` is echoed back
    /// so the new version records what it was built from.
    static func accept(recipeId: String, proposal: ProposalEdit) async throws {
        let tmxSteps = proposal.tmxSteps.map { GraphQLHelpers.tmxSettingsInput($0) }
        let input = ShuhariGraphQL.ProposalInput(
            basedOn: proposal.basedOn,
            changeSummary: proposal.changeSummary,
            ingredients: proposal.ingredients.map { ShuhariGraphQL.IngredientInput(name: $0.name, quantity: $0.quantity) },
            rationale: proposal.rationale,
            steps: proposal.steps,
            tmxSteps: tmxSteps
        )

        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.AcceptProposalMutation(recipeId: recipeId, proposal: input)
        )
    }
}
