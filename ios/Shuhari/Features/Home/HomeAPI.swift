import Apollo
import Foundation

enum HomeAPI {
    static func getHome() async throws -> HomeData {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShuhariGraphQL.HomeQuery()
        )
        let home = data.home
        return HomeData(
            toTest: home.toTest.compactMap { recipe in
                guard let version = recipe.toTest else { return nil }
                return HomeTestItem(
                    id: recipe.id,
                    title: recipe.title,
                    type: RecipeType(graphql: recipe.type),
                    category: DishCategory(graphql: recipe.category),
                    versionNumber: version.number,
                    change: version.change,
                    why: version.why ?? version.originDetail
                )
            },
            library: home.library.map { recipe in
                LibraryRecipe(
                    id: recipe.id,
                    title: recipe.title,
                    type: RecipeType(graphql: recipe.type),
                    category: DishCategory(graphql: recipe.category),
                    versionCount: recipe.versionCount,
                    bestNote: recipe.bestNote,
                    averageNote: recipe.currentVersion?.note.map(Double.init),
                    updatedAt: GraphQLHelpers.parseISO8601(recipe.updatedAt) ?? Date.distantPast
                )
            },
            recentEssais: home.recentEssais.compactMap { essai in
                guard let note = essai.note, let executedAt = essai.executedAt else { return nil }
                return RecentEssai(
                    recipeId: essai.recipeId,
                    versionNumber: essai.number,
                    note: note,
                    remarks: essai.remarks ?? "",
                    executedAt: GraphQLHelpers.parseISO8601(executedAt) ?? Date()
                )
            }
        )
    }
}
