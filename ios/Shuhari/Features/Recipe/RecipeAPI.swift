import Apollo
import Foundation

enum RecipeAPI {
    // MARK: - Queries

    static func getRecipe(id: String) async throws -> Recipe {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShuhariGraphQL.RecipeQuery(id: id)
        )
        guard let recipe = data.recipe else { throw APIError.invalidResponse }
        return mapRecipe(recipe)
    }

    // MARK: - Mutations

    static func deleteRecipe(id: String) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.DeleteRecipeMutation(id: id)
        )
    }

    static func updateRecipe(id: String, title: String?, subtitle: String?) async throws {
        let input = ShuhariGraphQL.UpdateRecipeInput(
            subtitle: GraphQLHelpers.graphQLNullable(subtitle),
            title: GraphQLHelpers.graphQLNullable(title)
        )
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.UpdateRecipeMutation(id: id, input: input)
        )
    }
}

// MARK: - Mapping

func mapRecipe(_ r: ShuhariGraphQL.RecipeQuery.Data.Recipe) -> Recipe {
    Recipe(
        id: r.id,
        title: r.title,
        subtitle: r.subtitle,
        type: RecipeType(graphql: r.type),
        category: DishCategory(graphql: r.category),
        createdAt: GraphQLHelpers.parseISO8601(r.createdAt) ?? Date(),
        updatedAt: GraphQLHelpers.parseISO8601(r.updatedAt) ?? Date(),
        versions: r.versions.map { mapVersion($0.fragments.versionFields) },
        bestNote: r.bestNote,
        versionToOpen: mapVersion(r.versionToOpen.fragments.versionFields)
    )
}

func mapVersion(_ v: ShuhariGraphQL.VersionFields) -> RecipeVersion {
    RecipeVersion(
        number: v.number,
        basedOn: v.basedOn,
        change: v.change,
        why: v.why,
        originKind: VersionOriginKind(graphql: v.originKind),
        originDetail: v.originDetail,
        ingredients: v.ingredients.map { Ingredient(name: $0.name, quantity: $0.quantity) },
        steps: v.steps,
        tmxSteps: v.tmxSteps.map { step in
            step.map { TmxSettings(time: $0.time, temperature: $0.temperature, speed: $0.speed, reverse: $0.reverse ?? false) }
        },
        recipeId: v.recipeId,
        note: v.note,
        remarks: v.remarks,
        executedAt: v.executedAt.flatMap { GraphQLHelpers.parseISO8601($0) },
        photoUrl: v.photoUrl,
        createdAt: GraphQLHelpers.parseISO8601(v.createdAt) ?? Date()
    )
}

func mapProposition(_ d: ShuhariGraphQL.PropositionFields) -> Proposition {
    Proposition(
        basedOn: d.basedOn,
        changeSummary: d.changeSummary,
        rationale: d.rationale,
        ingredients: d.ingredients.map { Ingredient(name: $0.name, quantity: $0.quantity) },
        steps: d.steps,
        tmxSteps: d.tmxSteps.map { step in
            step.map { TmxSettings(time: $0.time, temperature: $0.temperature, speed: $0.speed, reverse: $0.reverse ?? false) }
        }
    )
}
