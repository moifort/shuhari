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
            title: analysis.title,
            subtitle: analysis.subtitle,
            type: RecipeType(graphql: analysis.type),
            params: analysis.params.map { Param(key: $0.key, value: $0.value) },
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
        let input = ShuhariGraphQL.CreateRecipeInput(
            params: analysis.params.map { ShuhariGraphQL.ParamInput(key: $0.key, value: $0.value) },
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
}
