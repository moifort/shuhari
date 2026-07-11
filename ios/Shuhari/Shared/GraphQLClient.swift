import Apollo
import ApolloAPI
import Foundation

/// Singleton ApolloClient configured for the Firebase Functions /graphql endpoint.
/// Each request goes through:
///   1. FirebaseTokenInterceptor — injects Authorization: Bearer <ID Token>
///   2. (Apollo default chain — parsing, error handling)
///   3. GraphQLLoggingInterceptor — logs operation name + GraphQL errors
final class GraphQLClient: @unchecked Sendable {
    static let shared = GraphQLClient()

    // Built once: recreating the store/transport per request would discard
    // connection reuse. The base URL is read at init — changing the server URL
    // in the debug settings requires an app restart.
    let apollo: ApolloClient

    private init() {
        let url = APIClient.shared.baseURL.appendingPathComponent("graphql")
        let store = ApolloStore()
        let interceptorProvider = AuthenticatedInterceptorProvider(store: store)
        let transport = RequestChainNetworkTransport(
            interceptorProvider: interceptorProvider,
            endpointURL: url
        )
        apollo = ApolloClient(networkTransport: transport, store: store)
    }
}

final class AuthenticatedInterceptorProvider: DefaultInterceptorProvider {
    override func interceptors<O: GraphQLOperation>(for operation: O) -> [any ApolloInterceptor] {
        var list = super.interceptors(for: operation)
        list.insert(FirebaseTokenInterceptor(), at: 0)
        list.append(GraphQLLoggingInterceptor())
        return list
    }
}
