import Apollo
import Foundation

enum SettingsAPI {
    static func loadChangelog() async throws -> [ChangelogVersion] {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShuhariGraphQL.ChangelogQuery()
        )
        return data.changelog.map { entry in
            ChangelogVersion(
                version: entry.version,
                date: entry.date.flatMap { GraphQLHelpers.parseISO8601($0) },
                notes: entry.notes
            )
        }
    }

    static func exportData() async throws -> String {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShuhariGraphQL.ExportDataQuery()
        )
        return data.exportData
    }

    static func importData(payload: String) async throws -> ImportSummary {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.ImportDataMutation(payload: payload)
        )
        let result = data.importData
        return ImportSummary(
            recipes: result.recipes,
            versions: result.versions,
            trials: result.trials
        )
    }
}
