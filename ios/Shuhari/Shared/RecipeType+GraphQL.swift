import ApolloAPI

/// Bridges the generated `ShuhariGraphQL.RecipeType` enum and the design-facing
/// `RecipeType` (which carries its label and icons).
extension RecipeType {
    init(graphql: GraphQLEnum<ShuhariGraphQL.RecipeType>) {
        switch graphql {
        case .case(let value):
            switch value {
            case .plat: self = .plat
            case .tmx: self = .tmx
            }
        case .unknown:
            self = .plat
        }
    }

    var graphQLValue: GraphQLEnum<ShuhariGraphQL.RecipeType> {
        switch self {
        case .plat: .case(.plat)
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

/// Recommendation bridge.
extension ProposalRecommendation {
    init(graphql: GraphQLEnum<ShuhariGraphQL.ProposalRecommendation>) {
        switch graphql {
        case .case(let value):
            switch value {
            case .iteration: self = .iteration
            case .variation: self = .variation
            }
        case .unknown:
            self = .iteration
        }
    }

    var graphQLValue: GraphQLEnum<ShuhariGraphQL.ProposalRecommendation> {
        switch self {
        case .iteration: .case(.iteration)
        case .variation: .case(.variation)
        }
    }
}
