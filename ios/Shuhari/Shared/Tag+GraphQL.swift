import ApolloAPI

/// Bridges the generated `ShuhariGraphQL.TagIcon` enum and the design-facing
/// `TagIcon` (which carries the drawings). An icon this build does not know is no
/// icon at all: the tag keeps its words and simply leaves the library row.
extension TagIcon {
    init?(graphql: GraphQLEnum<ShuhariGraphQL.TagIcon>?) {
        guard case .case(let value) = graphql else { return nil }
        switch value {
        case .thermomix: self = .thermomix
        case .oven: self = .oven
        case .microwave: self = .microwave
        case .barbecue: self = .barbecue
        case .pan: self = .pan
        case .freezer: self = .freezer
        case .quick: self = .quick
        case .slow: self = .slow
        case .vegetarian: self = .vegetarian
        case .fish: self = .fish
        case .guests: self = .guests
        case .kids: self = .kids
        case .festive: self = .festive
        }
    }

    var graphQLValue: GraphQLEnum<ShuhariGraphQL.TagIcon> {
        switch self {
        case .thermomix: .case(.thermomix)
        case .oven: .case(.oven)
        case .microwave: .case(.microwave)
        case .barbecue: .case(.barbecue)
        case .pan: .case(.pan)
        case .freezer: .case(.freezer)
        case .quick: .case(.quick)
        case .slow: .case(.slow)
        case .vegetarian: .case(.vegetarian)
        case .fish: .case(.fish)
        case .guests: .case(.guests)
        case .kids: .case(.kids)
        case .festive: .case(.festive)
        }
    }
}
