import SwiftUI

struct SettingsHomeView: View {
    /// Forwarded to the import/export screen so a "replace all data" import can
    /// refresh the caller's recipe list.
    var onDataReplaced: () async -> Void = {}
    @Environment(AuthSession.self) private var authSession
    @Environment(SubscriptionStore.self) private var subscription
    @Environment(\.dismiss) private var dismiss
    @State private var signOutError: String?
    @State private var confirmDelete = false
    @State private var isDeleting = false
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

                Section("Compte") {
                    if let email = authSession.user?.email {
                        Text(email).foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        HStack {
                            Text("Supprimer mon compte")
                            if isDeleting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isDeleting)
                    .accessibilityIdentifier("delete-account-button")
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
            // Everything the deletion takes is named, and the one thing it cannot do —
            // stop an App Store subscription — is said before the button is pressed,
            // not discovered on the next bank statement.
            .alert("Supprimer mon compte ?", isPresented: $confirmDelete) {
                Button("Supprimer définitivement", role: .destructive) { Task { await deleteAccount() } }
                Button("Gérer mes abonnements") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text(
                    "Toutes tes recettes, leurs versions et tes essais seront effacés "
                        + "définitivement. Cette action est irréversible.\n\n"
                        + "Un abonnement Premium en cours continue d'être facturé : "
                        + "il se résilie depuis les réglages de l'iPhone."
                )
            }
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await authSession.deleteAccount()
            dismiss()
        } catch AppleReauthentication.Failure.canceled {
            // Backing out of the Apple sheet is a decision, not a failure: nothing
            // has been deleted, and an error alert would suggest otherwise.
        } catch {
            signOutError = reportError(error)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
}
