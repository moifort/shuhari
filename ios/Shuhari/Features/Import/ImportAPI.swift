import Apollo
import ApolloAPI
import Foundation

enum ImportAPI {
    enum Source {
        case photos([String]) // base64 JPEGs, no data-URL prefix
        case url(String)
        case text(String)
    }

    /// Analyze an import source into a structured, editable recipe preview.
    static func analyze(_ source: Source) async throws -> ImportAnalysis {
        var photos: GraphQLNullable<[String]> = .none
        var url: GraphQLNullable<String> = .none
        var text: GraphQLNullable<String> = .none
        switch source {
        case .photos(let list): photos = .some(list)
        case .url(let value): url = GraphQLHelpers.graphQLNullable(value)
        case .text(let value): text = GraphQLHelpers.graphQLNullable(value)
        }

        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.AnalyzeImportMutation(photos: photos, url: url, text: text)
        )
        let analysis = data.analyzeImport
        return ImportAnalysis(
            title: normalizedTitle(analysis.title),
            subtitle: analysis.subtitle,
            type: RecipeType(graphql: analysis.type),
            category: DishCategory(graphql: analysis.category),
            ingredients: analysis.ingredients.map { Ingredient(name: $0.name, quantity: $0.quantity) },
            steps: analysis.steps,
            tmxSteps: analysis.tmxSteps.map { list in
                list.map { $0.map { TmxSettings(time: $0.time, temperature: $0.temperature, speed: $0.speed, reverse: $0.reverse ?? false) } }
            },
            sourceLabel: analysis.sourceLabel
        )
    }

    /// Create a recipe and its v1 from a confirmed preview. Returns the recipe id.
    static func create(_ analysis: ImportAnalysis) async throws -> String {
        let tmxSteps: GraphQLNullable<[ShuhariGraphQL.TmxSettingsInput?]> = analysis.tmxSteps
            .map { list in
                .some(list.map { settings in
                    settings.map {
                        ShuhariGraphQL.TmxSettingsInput(
                            reverse: $0.reverse ? .some(true) : .none,
                            speed: GraphQLHelpers.graphQLNullable($0.speed),
                            temperature: GraphQLHelpers.graphQLNullable($0.temperature),
                            time: GraphQLHelpers.graphQLNullable($0.time)
                        )
                    }
                })
            } ?? .none
        let ingredients: GraphQLNullable<[ShuhariGraphQL.IngredientInput]> = analysis.ingredients.isEmpty
            ? .none
            : .some(analysis.ingredients.map { ShuhariGraphQL.IngredientInput(name: $0.name, quantity: $0.quantity) })
        let input = ShuhariGraphQL.CreateRecipeInput(
            category: analysis.category.graphQLValue,
            ingredients: ingredients,
            sourceLabel: GraphQLHelpers.graphQLNullable(analysis.sourceLabel),
            steps: analysis.steps,
            subtitle: GraphQLHelpers.graphQLNullable(analysis.subtitle),
            title: analysis.title,
            tmxSteps: tmxSteps,
            type: analysis.type.graphQLValue
        )
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.CreateRecipeMutation(input: input)
        )
        return data.createRecipe.id
    }

    /// AI sources sometimes hand back an all-caps title ("COOKIES AUX NOIX DE
    /// PÉCAN"). Normalize a fully-uppercase title to sentence case; leave any
    /// mixed-case title untouched (it's already how the source wrote it).
    private static func normalizedTitle(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == trimmed.uppercased(), trimmed != trimmed.lowercased() else { return trimmed }
        return trimmed.prefix(1).uppercased() + trimmed.dropFirst().lowercased()
    }
}
