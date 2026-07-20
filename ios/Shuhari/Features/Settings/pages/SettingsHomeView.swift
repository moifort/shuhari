import SwiftUI

struct SettingsHomeView: View {
    /// Forwarded to the import/export screen so a "replace all data" import can
    /// refresh the caller's recipe list.
    var onDataReplaced: () async -> Void = {}
    @Environment(AuthSession.self) private var authSession
    @Environment(SubscriptionStore.self) private var subscription
    @Environment(\.dismiss) private var dismiss
    @State private var signOutError: String?
    /// The AI allowance, loaded on appear. Absent until it answers — the section
    /// stays out of the list rather than showing empty meters.
    @State private var quota: QuotaState?
    @State private var showPremium = false

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

                if let quota {
                    QuotaSection(
                        isPremium: quota.isPremium,
                        meters: [
                            .init(
                                title: "Imports IA",
                                icon: "square.and.arrow.down",
                                used: quota.imports.used,
                                limit: quota.imports.limit
                            ),
                            .init(
                                title: "Itérations IA",
                                icon: "sparkles",
                                used: quota.iterations.used,
                                limit: quota.iterations.limit
                            ),
                        ],
                        renewsOn: quota.renewsOn,
                        onUpgrade: { showPremium = true }
                    )
                }

                Section("Données") {
                    NavigationLink {
                        ImportExportSettingsView(onDataReplaced: onDataReplaced)
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
            .task { quota = try? await QuotaAPI.load() }
            .sheet(isPresented: $showPremium, onDismiss: { Task { quota = try? await QuotaAPI.load() } }) {
                PremiumSheet(store: subscription)
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Fermer")
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
