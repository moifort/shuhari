import Apollo
import Foundation

enum ExecutionAPI {
    /// Record an essai onto a version (fast, no AI). Overwritable — recording again
    /// on the same version updates it. Returns the version with its outcome.
    @discardableResult
    static func recordEssai(
        recipeId: String,
        versionNumber: Int,
        note: Int,
        remarks: String,
        photoBase64: String?
    ) async throws -> RecipeVersion {
        let input = ShuhariGraphQL.RecordEssaiInput(
            note: note,
            photo: GraphQLHelpers.graphQLNullable(photoBase64),
            recipeId: recipeId,
            remarks: remarks,
            versionNumber: versionNumber
        )
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.RecordEssaiMutation(input: input)
        )
        return mapVersion(data.recordEssai.fragments.versionFields)
    }

    /// Ask the AI to analyze the cooked version and propose the next one.
    @discardableResult
    static func requestProposition(recipeId: String, versionNumber: Int) async throws -> Proposition {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.RequestProposalMutation(recipeId: recipeId, versionNumber: versionNumber)
        )
        return mapProposition(data.requestProposal.fragments.proposalFields)
    }
}
