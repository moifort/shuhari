import SwiftUI

struct ChangelogListView: View {
    @State private var entries: [ChangelogVersion] = []
    @State private var error: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Chargement…")
            } else if let error {
                ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if entries.isEmpty {
                ContentUnavailableView("Aucune entrée", systemImage: "doc.text")
            } else {
                List(entries) { entry in
                    ChangelogEntryRow(version: entry.version, date: entry.date, notes: entry.notes)
                }
            }
        }
        .navigationTitle("Version & changelog")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            entries = try await SettingsAPI.loadChangelog()
            error = nil
        } catch {
            self.error = reportError(error)
        }
        isLoading = false
    }
}
