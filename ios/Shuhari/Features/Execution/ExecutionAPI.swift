import Apollo
import Foundation

enum ExecutionAPI {
    struct TrialResult: Sendable {
        let trial: Trial
        let promotionSuggested: Bool
    }

    /// Record a trial (fast, no AI).
    static func recordTrial(
        recipeId: String,
        versionNumber: Int,
        note: Int,
        remarks: String,
        photoBase64: String?
    ) async throws -> TrialResult {
        let input = ShuhariGraphQL.RecordTrialInput(
            note: note,
            photo: GraphQLHelpers.graphQLNullable(photoBase64),
            recipeId: recipeId,
            remarks: remarks,
            versionNumber: versionNumber
        )
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.RecordTrialMutation(input: input)
        )
        let result = data.recordTrial
        return TrialResult(
            trial: mapTrial(result.trial.fragments.trialFields),
            promotionSuggested: result.promotionSuggested
        )
    }

    /// Ask the AI to analyze the latest trials and propose the next step.
    @discardableResult
    static func requestProposal(recipeId: String) async throws -> Proposal {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.RequestProposalMutation(recipeId: recipeId)
        )
        return mapProposal(data.requestProposal.fragments.proposalFields)
    }
}
