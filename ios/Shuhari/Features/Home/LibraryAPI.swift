import Apollo
import ApolloAPI
import Foundation

/// One page of the recipe library, mirroring the server's `Recipes` payload.
struct RecipePage: Sendable {
    let items: [LibraryRecipe]
    let hasMore: Bool
    let totalCount: Int
}

/// The paginated recipe library — the `recipes(...)` query: it scrolls infinitely
/// and sorts server-side, and is the notebook's sole read model.
enum LibraryAPI {
    static func list(
        type: RecipeType?,
        category: DishCategory?,
        favorite: Bool,
        sort: RecipeSortOption,
        limit: Int,
        after: String?
    ) async throws -> RecipePage {
        let query = ShuhariGraphQL.RecipeListQuery(
            type: type.map { .some($0.graphQLValue) } ?? .none,
            category: category.map { .some($0.graphQLValue) } ?? .none,
            favorite: favorite ? .some(true) : .none,
            sort: .some(.case(gqlSort(sort))),
            order: .some(.case(gqlOrder(sort))),
            limit: .some(limit),
            after: GraphQLHelpers.graphQLNullable(after)
        )
        let data = try await GraphQLHelpers.fetch(GraphQLClient.shared.apollo, query: query)
        let recipes = data.recipes
        return RecipePage(
            items: recipes.items.map { recipe in
                LibraryRecipe(
                    id: recipe.id,
                    title: recipe.title,
                    type: RecipeType(graphql: recipe.type),
                    category: DishCategory(graphql: recipe.category),
                    favorite: recipe.favorite,
                    versionCount: recipe.versionCount,
                    attemptCount: recipe.attemptCount,
                    bestRating: recipe.bestRating,
                    updatedAt: GraphQLHelpers.parseISO8601(recipe.updatedAt) ?? Date.distantPast
                )
            },
            hasMore: recipes.hasMore,
            totalCount: recipes.totalCount
        )
    }
}

// MARK: - Mapping helpers

/// The category sort is a fixed business order — the server ignores `order` for it —
/// but a valid value is still required on the wire.
private func gqlSort(_ sort: RecipeSortOption) -> ShuhariGraphQL.RecipeSort {
    switch sort {
    case .lastModified: .updatedAt
    case .dishCategory: .category
    }
}

private func gqlOrder(_ sort: RecipeSortOption) -> ShuhariGraphQL.SortOrder {
    switch sort {
    case .lastModified: .desc
    case .dishCategory: .desc
    }
}
