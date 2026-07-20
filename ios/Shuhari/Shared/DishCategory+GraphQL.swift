import ApolloAPI

/// Bridges the generated `ShuhariGraphQL.DishCategory` enum and the design-facing
/// `DishCategory` (which carries labels and icons). Kept separate from the
/// `RecipeType` bridge on purpose: `DishCategory.main` and `RecipeType.dish` are
/// distinct enums that must never share a helper.
extension DishCategory {
    init(graphql: GraphQLEnum<ShuhariGraphQL.DishCategory>) {
        switch graphql {
        case .case(let value):
            switch value {
            case .starter: self = .starter
            case .main: self = .main
            case .dessert: self = .dessert
            case .soup: self = .soup
            case .sauce: self = .sauce
            case .baking: self = .baking
            case .drink: self = .drink
            }
        case .unknown:
            self = .main
        }
    }

    var graphQLValue: GraphQLEnum<ShuhariGraphQL.DishCategory> {
        switch self {
        case .starter: .case(.starter)
        case .main: .case(.main)
        case .dessert: .case(.dessert)
        case .soup: .case(.soup)
        case .sauce: .case(.sauce)
        case .baking: .case(.baking)
        case .drink: .case(.drink)
        }
    }
}
