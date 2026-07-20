import Apollo
import ApolloAPI
import Foundation

enum ProposalAPI {
    /// Accept the proposal as an iteration. The proposal FULLY REPLACES the
    /// next version — the lists are complete, not partial. `basedOn` is echoed back
    /// so the new version records what it was built from, and the attempt that asked
    /// for it (rating, remarks, photo) is recorded on that new version — this is the
    /// only moment that cook is written down. No attempt means the proposal answers
    /// an improvement: the version created lands on the to-cook list instead.
    static func accept(recipeId: String, proposal: ProposalEdit, attempt: Attempt?) async throws {
        let input = ShuhariGraphQL.ProposalInput(
            basedOn: proposal.basedOn,
            changeSummary: proposal.changeSummary,
            content: GraphQLHelpers.versionContentInput(proposal.content),
            photo: GraphQLHelpers.graphQLNullable(attempt?.photoBase64),
            rating: GraphQLHelpers.graphQLNullable(attempt?.rating),
            rationale: proposal.rationale,
            remarks: GraphQLHelpers.graphQLNullable(attempt?.remarks),
            tips: proposal.tips
        )

        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.AcceptProposalMutation(recipeId: recipeId, proposal: input)
        )
    }

    /// Ask the AI for a next version answering what the cook wants improved. Nothing
    /// is saved: the proposal is reviewed, then accepted (or dropped).
    static func requestImprovement(
        recipeId: String,
        versionNumber: Int,
        improvement: String
    ) async throws -> Proposal {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.RequestImprovementMutation(
                recipeId: recipeId,
                versionNumber: versionNumber,
                improvement: improvement
            )
        )
        return mapProposal(data.requestImprovement.fragments.proposalFields)
    }

    /// Ask the AI to fold the tips the cook just typed into the version's own tips —
    /// reworded, merged, deduplicated. Nothing is saved: the complete list comes back
    /// to review, and accepting it goes through `updateTips`.
    static func requestTips(
        recipeId: String,
        versionNumber: Int,
        tips: String
    ) async throws -> [String] {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.RequestTipsMutation(
                recipeId: recipeId,
                versionNumber: versionNumber,
                tips: tips
            )
        )
        return data.requestTips.tips
    }

    /// Replace one version's tips with this complete list. No version is created:
    /// the tips are the one part of a version, beside its outcome, that is rewritten
    /// in place.
    static func updateTips(recipeId: String, versionNumber: Int, tips: [String]) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.UpdateTipsMutation(
                recipeId: recipeId,
                versionNumber: versionNumber,
                tips: tips
            )
        )
    }
}
