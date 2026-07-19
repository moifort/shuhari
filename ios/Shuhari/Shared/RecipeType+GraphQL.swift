import ApolloAPI

/// Bridges the generated `ShuhariGraphQL.RecipeType` enum and the design-facing
/// `RecipeType` (which carries its label and icons).
extension RecipeType {
    init(graphql: GraphQLEnum<ShuhariGraphQL.RecipeType>) {
        switch graphql {
        case .case(let value):
            switch value {
            case .dish: self = .dish
            case .tmx: self = .tmx
            }
        case .unknown:
            self = .dish
        }
    }

    var graphQLValue: GraphQLEnum<ShuhariGraphQL.RecipeType> {
        switch self {
        case .dish: .case(.dish)
        case .tmx: .case(.tmx)
        }
    }
}

/// Origin kind bridge (used by the history timeline copy).
extension VersionOriginKind {
    init(graphql: GraphQLEnum<ShuhariGraphQL.VersionOriginKind>) {
        switch graphql {
        case .case(let value):
            switch value {
            case .aiProposal: self = .aiProposal
            case .import: self = .import
            case .manual: self = .manual
            }
        case .unknown:
            self = .manual
        }
    }
}
