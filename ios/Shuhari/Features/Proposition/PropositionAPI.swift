import Apollo
import ApolloAPI
import Foundation

enum PropositionAPI {
    /// Accept the proposition as an iteration. The proposition FULLY REPLACES the
    /// next version — the lists are complete, not partial. `basedOn` is echoed back
    /// so the new version records what it was built from.
    static func accept(recipeId: String, proposition: PropositionEdit) async throws {
        let tmxSteps: GraphQLNullable<[ShuhariGraphQL.TmxSettingsInput?]> = proposition.tmxSteps.isEmpty
            ? .none
            : .some(proposition.tmxSteps.map { settings in
                settings.map {
                    ShuhariGraphQL.TmxSettingsInput(
                        reverse: $0.reverse ? .some(true) : .none,
                        speed: GraphQLHelpers.graphQLNullable($0.speed),
                        temperature: GraphQLHelpers.graphQLNullable($0.temperature),
                        time: GraphQLHelpers.graphQLNullable($0.time)
                    )
                }
            })
        let input = ShuhariGraphQL.PropositionInput(
            basedOn: proposition.basedOn,
            changeSummary: proposition.changeSummary,
            ingredients: proposition.ingredients.map { ShuhariGraphQL.IngredientInput(name: $0.name, quantity: $0.quantity) },
            rationale: proposition.rationale,
            steps: proposition.steps,
            tmxSteps: tmxSteps
        )

        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.AcceptPropositionMutation(recipeId: recipeId, proposition: input)
        )
    }
}
