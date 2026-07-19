import Apollo
import Foundation

enum ExecutionAPI {
    /// Record an attempt onto a version (fast, no AI). Overwritable — recording again
    /// on the same version updates it. Returns the version with its outcome.
    @discardableResult
    static func recordAttempt(
        recipeId: String,
        versionNumber: Int,
        rating: Int,
        remarks: String,
        photoBase64: String?
    ) async throws -> RecipeVersion {
        let input = ShuhariGraphQL.RecordAttemptInput(
            photo: GraphQLHelpers.graphQLNullable(photoBase64),
            rating: rating,
            recipeId: recipeId,
            remarks: remarks,
            versionNumber: versionNumber
        )
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.RecordAttemptMutation(input: input)
        )
        return mapVersion(data.recordAttempt.fragments.versionFields)
    }

    /// Ask the AI to analyze the cooked version and propose the next one.
    @discardableResult
    static func requestProposal(recipeId: String, versionNumber: Int) async throws -> Proposal {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.RequestProposalMutation(recipeId: recipeId, versionNumber: versionNumber)
        )
        return mapProposal(data.requestProposal.fragments.proposalFields)
    }
}
