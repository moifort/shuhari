import SwiftUI

struct SettingsHomeView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(\.dismiss) private var dismiss
    @State private var signOutError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Application") {
                    NavigationLink {
                        ChangelogListView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Version & changelog")
                                Text("v\(appVersion) (\(buildNumber))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.text.fill").foregroundStyle(.indigo)
                        }
                    }
                }

                Section("Données") {
                    NavigationLink {
                        ImportExportSettingsView()
                    } label: {
                        Label("Importer / Exporter", systemImage: "square.and.arrow.up.fill")
                    }
                }

                if let email = authSession.user?.email {
                    Section("Compte") {
                        Text(email).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Se déconnecter", role: .destructive) {
                        do {
                            try authSession.signOut()
                            dismiss()
                        } catch {
                            signOutError = reportError(error)
                        }
                    }
                    .accessibilityIdentifier("sign-out-button")
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
            .alert("Erreur", isPresented: Binding(get: { signOutError != nil }, set: { if !$0 { signOutError = nil } })) {
                Button("OK") { signOutError = nil }
            } message: {
                Text(signOutError ?? "")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
}
