import Apollo
import Foundation

enum ExecutionAPI {
    struct EssaiResult: Sendable {
        let promotionSuggested: Bool
    }

    /// Record an essai onto a version (fast, no AI).
    static func recordEssai(
        recipeId: String,
        versionNumber: Int,
        note: Int,
        remarks: String,
        photoBase64: String?
    ) async throws -> EssaiResult {
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
        return EssaiResult(promotionSuggested: data.recordEssai.promotionSuggested)
    }

    /// Ask the AI to analyze the latest essai and draft the next version.
    @discardableResult
    static func requestDraft(recipeId: String) async throws -> Draft {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.RequestDraftMutation(recipeId: recipeId)
        )
        return mapDraft(data.requestDraft.fragments.draftFields)
    }
}
