import Apollo
import ApolloAPI
import Foundation

enum ProposalAPI {
    /// Accept the proposal as an iteration. The proposal FULLY REPLACES the
    /// next version — the lists are complete, not partial. `basedOn` is echoed back
    /// so the new version records what it was built from.
    static func accept(recipeId: String, proposal: ProposalEdit) async throws {
        let input = ShuhariGraphQL.ProposalInput(
            basedOn: proposal.basedOn,
            changeSummary: proposal.changeSummary,
            content: GraphQLHelpers.versionContentInput(proposal.content),
            rationale: proposal.rationale
        )

        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.AcceptProposalMutation(recipeId: recipeId, proposal: input)
        )
    }
}
