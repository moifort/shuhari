import XCTest

/// Experimentation loop: import a recipe, execute its current version, record a
/// low-scoring trial, receive an AI proposal, validate it as an iteration, and
/// see the new pending version surface as "à tester".
final class TrialLoopFlowTest: BaseUITest {

    func testTrialToProposalToPendingVersion() async throws {
        let tabBar = TabBarPage(app: app)
        try tabBar.verify()

        // 1. Seed a recipe through the import flow.
        let importPage = try tabBar.goToImport().openTextEntry()
        _ = try importPage.typeRecipe("Espresso : 18 g de café, mouture 2.0, sortie 36 g, 93 °C, 25 s.")
        let recipe = try importPage.analyze().verify().save()
        try recipe.verify()

        // 2. Record a trial for the fresh recipe via the round centre CTA
        //    (no pending "à tester" version yet).
        let capture = try recipe.recordTrial().verify()

        // 3. Record a low-scoring trial → triggers an AI proposal.
        _ = try capture.pickStars(3) // 3/5 < 4 → proposition
        _ = try capture.typeRemarks("Coule trop vite, amertume sèche en finale.")
        try capture.save()

        // 4. Proposal → validate as an iteration.
        let proposal = ProposalPage(app: app)
        try proposal.verify()
        _ = try proposal.chooseIteration()
        try proposal.validate()

        // 5. Back on the fiche, the pending v2 banner is now present.
        try recipe.verifyPendingVersion(2)
    }
}
