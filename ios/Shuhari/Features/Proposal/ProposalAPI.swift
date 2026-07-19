import Apollo
import ApolloAPI
import Foundation

enum ProposalAPI {
    /// Accept the proposal as an iteration. The proposal FULLY REPLACES the
    /// next version — the lists are complete, not partial. `basedOn` is echoed back
    /// so the new version records what it was built from, and the attempt that asked
    /// for it (rating, remarks, photo) is recorded on that new version — this is the
    /// only moment that cook is written down.
    static func accept(recipeId: String, proposal: ProposalEdit, attempt: Attempt) async throws {
        let input = ShuhariGraphQL.ProposalInput(
            basedOn: proposal.basedOn,
            changeSummary: proposal.changeSummary,
            content: GraphQLHelpers.versionContentInput(proposal.content),
            photo: GraphQLHelpers.graphQLNullable(attempt.photoBase64),
            rating: attempt.rating,
            rationale: proposal.rationale,
            remarks: attempt.remarks
        )

        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.AcceptProposalMutation(recipeId: recipeId, proposal: input)
        )
    }
}
