import Apollo
import Foundation

enum ProposalAPI {
    static func accept(
        recipeId: String,
        versionNumber: Int,
        choice: ProposalRecommendation,
        editedVars: [ProposalVar]?
    ) async throws {
        let vars = editedVars.map { list in
            list.map { ShuhariGraphQL.ProposalVarInput(
                from: GraphQLHelpers.graphQLNullable($0.from),
                key: $0.key,
                to: $0.to
            ) }
        }
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.AcceptProposalMutation(
                recipeId: recipeId,
                versionNumber: versionNumber,
                choice: choice.graphQLValue,
                editedVars: GraphQLHelpers.graphQLNullable(vars)
            )
        )
    }

    static func refuse(recipeId: String, versionNumber: Int) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.RefuseProposalMutation(recipeId: recipeId, versionNumber: versionNumber)
        )
    }
}
