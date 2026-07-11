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
                    currentVersionNumber: recipe.currentVersion?.number,
                    averageNote: recipe.currentVersion?.averageNote,
                    toTestNumber: recipe.toTest?.number,
                    isDerived: recipe.derivedFrom != nil
                )
            },
            recentTrials: home.recentTrials.map { trial in
                Trial(
                    id: trial.id,
                    recipeId: trial.recipeId,
                    versionNumber: trial.versionNumber,
                    note: trial.note,
                    remarks: trial.remarks,
                    realParams: [],
                    photoUrl: nil,
                    executedAt: GraphQLHelpers.parseISO8601(trial.executedAt) ?? Date()
                )
            }
        )
    }
}
