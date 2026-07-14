#if DEBUG
import SwiftUI

/// Debug-only screen gallery: renders any page with `Fixtures` data, without a
/// server or a signed-in user. Launch the app with `-gallery <screen>` (backed
/// by the `gallery` UserDefault) to jump straight to a screen — used to review
/// the design in the simulator and to capture screenshots.
struct DebugGallery: View {
    let screen: String

    var body: some View {
        switch screen {
        case "root":
            ContentView()
                .environment(HomeStore())
        case "home":
            NavigationStack {
                HomePage(data: Fixtures.homeData, title: "Café", onExecute: { _ in }, onSettings: {})
            }
        case "recipe":
            NavigationStack {
                RecipeDetailPage(recipe: Fixtures.espresso, onExecute: { _ in })
            }
        case "recipe-tmx":
            NavigationStack {
                RecipeDetailPage(recipe: Fixtures.risotto, onExecute: { _ in })
            }
        case "history":
            NavigationStack {
                HistoryPage(recipe: Fixtures.espresso)
            }
        case "trial":
            NavigationStack {
                TrialDetailPage(
                    recipeTitle: Fixtures.espresso.title,
                    trial: Fixtures.espressoTrials[1],
                    versionTargets: Fixtures.espressoV3.params,
                    onReplay: {}
                )
            }
        case "execute":
            NavigationStack {
                ExecutePage(
                    recipeTitle: Fixtures.espresso.title,
                    version: Fixtures.espressoV4,
                    replayParams: nil,
                    replayDate: nil,
                    onDone: {}
                )
            }
        case "execute-tmx":
            NavigationStack {
                ExecutePage(
                    recipeTitle: Fixtures.risotto.title,
                    version: Fixtures.risottoV2,
                    replayParams: nil,
                    replayDate: nil,
                    onDone: {}
                )
            }
        case "capture":
            NavigationStack {
                CapturePage(
                    recipeTitle: Fixtures.espresso.title,
                    targets: Fixtures.espressoV4.params,
                    isSaving: false,
                    onSave: { _, _, _, _ in }
                )
            }
        case "proposal":
            NavigationStack {
                ProposalPage(
                    recipeTitle: Fixtures.espresso.title,
                    type: .cafe,
                    proposal: Fixtures.proposal,
                    nextVersionNumber: 4,
                    variationTitle: Fixtures.proposal.variation?.title,
                    isWorking: false,
                    onRefuse: {},
                    onValidate: { _, _ in }
                )
            }
        case "import-preview":
            NavigationStack {
                ImportPreviewPage(analysis: Fixtures.importAnalysis, isSaving: false, onCancel: {}, onSave: { _ in })
            }
        case "ai-thinking":
            AIThinkingCard(message: "Analyse IA…")
        default:
            ContentUnavailableView(
                "Écran inconnu : \(screen)",
                systemImage: "questionmark.square.dashed",
                description: Text("Écrans : home, recipe, recipe-tmx, history, trial, execute, execute-tmx, capture, proposal, import-preview, ai-thinking")
            )
        }
    }
}
#endif
