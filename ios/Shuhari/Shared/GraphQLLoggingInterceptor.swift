import Apollo
import ApolloAPI
import Foundation
import OSLog

private let log = Logger(subsystem: "com.polyforms.shuhari.app", category: "graphql")

struct GraphQLLoggingInterceptor: ApolloInterceptor {
    let id = UUID().uuidString

    func interceptAsync<Operation: GraphQLOperation>(
        chain: any RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, any Error>) -> Void
    ) {
        if let result = response?.parsedResponse, let errors = result.errors, !errors.isEmpty {
            for error in errors {
                let code = (error.extensions?["code"] as? String) ?? "<no code>"
                let message = error.message ?? "<no message>"
                log.error(
                    "\(Operation.operationName, privacy: .public) [\(code, privacy: .public)] \(message, privacy: .public)"
                )
            }
        }
        chain.proceedAsync(
            request: request,
            response: response,
            interceptor: self,
            completion: completion
        )
    }
}
