import Apollo
import ApolloAPI
import Foundation

enum DraftAPI {
    /// Accept the draft as an iteration. The draft FULLY REPLACES the next version —
    /// the lists are complete, not partial.
    static func accept(recipeId: String, draft: DraftEdit) async throws {
        let tmxSteps: GraphQLNullable<[ShuhariGraphQL.TmxSettingsInput?]> = draft.tmxSteps.isEmpty
            ? .none
            : .some(draft.tmxSteps.map { settings in
                settings.map {
                    ShuhariGraphQL.TmxSettingsInput(
                        reverse: $0.reverse ? .some(true) : .none,
                        speed: GraphQLHelpers.graphQLNullable($0.speed),
                        temperature: GraphQLHelpers.graphQLNullable($0.temperature),
                        time: GraphQLHelpers.graphQLNullable($0.time)
                    )
                }
            })
        let input = ShuhariGraphQL.DraftInput(
            changeSummary: draft.changeSummary,
            ingredients: draft.ingredients.map { ShuhariGraphQL.IngredientInput(name: $0.name, quantity: $0.quantity) },
            rationale: draft.rationale,
            steps: draft.steps,
            tmxSteps: tmxSteps
        )

        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.AcceptDraftMutation(recipeId: recipeId, draft: input)
        )
    }
}
