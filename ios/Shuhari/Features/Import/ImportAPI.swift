import Apollo
import ApolloAPI
import Foundation

enum ImportAPI {
    enum Source {
        case photos([String]) // base64 JPEGs, no data-URL prefix
        case url(String)
        case text(String)
    }

    /// The AI scan ran fine but detected no recipe in the source.
    enum ImportError: Error { case noRecipeFound }

    /// Analyze an import source into a structured, editable recipe preview.
    static func analyze(_ source: Source) async throws -> ImportAnalysis {
        // The photo list is total: a URL/text import sends `[]`, never a null.
        var photos: [String] = []
        var url: GraphQLNullable<String> = .none
        var text: GraphQLNullable<String> = .none
        switch source {
        case .photos(let list): photos = list
        case .url(let value): url = GraphQLHelpers.graphQLNullable(value)
        case .text(let value): text = GraphQLHelpers.graphQLNullable(value)
        }

        let data: ShuhariGraphQL.AnalyzeImportMutation.Data
        do {
            data = try await GraphQLHelpers.perform(
                GraphQLClient.shared.apollo,
                mutation: ShuhariGraphQL.AnalyzeImportMutation(photos: photos, url: url, text: text)
            )
        } catch let error as APIError {
            if case .graphQL(_, let codes) = error, codes.contains("NO_RECIPE_FOUND") {
                throw ImportError.noRecipeFound
            }
            throw error
        }
        let analysis = data.analyzeImport
        return ImportAnalysis(
            title: normalizedTitle(analysis.title),
            type: RecipeType(graphql: analysis.type),
            category: DishCategory(graphql: analysis.category),
            ingredients: analysis.ingredients.map { Ingredient(name: $0.name, quantity: $0.quantity) },
            steps: analysis.steps.map { step in
                ThermomixStep(
                    text: step.text,
                    settings: ThermomixSettings(
                        time: step.settings.time,
                        temperature: step.settings.temperature,
                        speed: step.settings.speed,
                        reverse: step.settings.reverse ?? false
                    )
                )
            },
            sourceLabel: analysis.sourceLabel
        )
    }

    /// Create a recipe and its v1 from a confirmed preview. Returns the recipe id.
    /// The content arm mirrors the detected type: a dish keeps plain-text steps, a
    /// Thermomix recipe keeps each step's machine settings.
    static func create(_ analysis: ImportAnalysis) async throws -> String {
        let content: VersionContent
        switch analysis.type {
        case .dish:
            content = .dish(ingredients: analysis.ingredients, steps: analysis.steps.map(\.text))
        case .thermomix:
            content = .thermomix(ingredients: analysis.ingredients, steps: analysis.steps)
        }
        let input = ShuhariGraphQL.CreateRecipeInput(
            category: analysis.category.graphQLValue,
            content: GraphQLHelpers.versionContentInput(content),
            sourceLabel: GraphQLHelpers.graphQLNullable(analysis.sourceLabel),
            title: analysis.title,
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
