import ApolloAPI

/// Bridges the generated `ShuhariGraphQL.DishCategory` enum and the design-facing
/// `DishCategory` (which carries labels and icons). Kept separate from the
/// `RecipeType` bridge on purpose: `DishCategory.plat` and `RecipeType.plat` are
/// distinct enums that must never share a helper.
extension DishCategory {
    init(graphql: GraphQLEnum<ShuhariGraphQL.DishCategory>) {
        switch graphql {
        case .case(let value):
            switch value {
            case .entree: self = .entree
            case .plat: self = .plat
            case .dessert: self = .dessert
            case .soupe: self = .soupe
            case .sauce: self = .sauce
            case .boulangerie: self = .boulangerie
            }
        case .unknown:
            self = .plat
        }
    }

    var graphQLValue: GraphQLEnum<ShuhariGraphQL.DishCategory> {
        switch self {
        case .entree: .case(.entree)
        case .plat: .case(.plat)
        case .dessert: .case(.dessert)
        case .soupe: .case(.soupe)
        case .sauce: .case(.sauce)
        case .boulangerie: .case(.boulangerie)
        }
    }
}
