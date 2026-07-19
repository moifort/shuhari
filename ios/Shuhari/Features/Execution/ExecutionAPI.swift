import Apollo
import Foundation

enum ExecutionAPI {
    /// Record a remark-less cook onto the version cooked (fast, no AI). Overwritable —
    /// recording again on the same version updates it. Returns the version with its
    /// outcome. A cook that carries remarks does NOT go through here: it asks for a
    /// proposal, and lands on the version that answers it.
    @discardableResult
    static func recordAttempt(
        recipeId: String,
        versionNumber: Int,
        rating: Int,
        photoBase64: String?
    ) async throws -> RecipeVersion {
        let input = ShuhariGraphQL.RecordAttemptInput(
            photo: GraphQLHelpers.graphQLNullable(photoBase64),
            rating: rating,
            recipeId: recipeId,
            versionNumber: versionNumber
        )
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.RecordAttemptMutation(input: input)
        )
        return mapVersion(data.recordAttempt.fragments.versionFields)
    }

    /// Ask the AI to analyze the cooked version against how the cook went and propose
    /// the next one. The rating and remarks travel with the request: nothing of that
    /// cook is stored until the proposal is accepted.
    @discardableResult
    static func requestProposal(
        recipeId: String,
        versionNumber: Int,
        rating: Int,
        remarks: String
    ) async throws -> Proposal {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.RequestProposalMutation(
                recipeId: recipeId,
                versionNumber: versionNumber,
                rating: rating,
                remarks: remarks
            )
        )
        return mapProposal(data.requestProposal.fragments.proposalFields)
    }
}
