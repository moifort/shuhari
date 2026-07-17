import XCTest

/// Experimentation loop: import a recipe, execute its current version, record a
/// low-scoring trial, receive an AI draft, validate it as an iteration, and
/// see the new pending version surface as "à tester".
final class TrialLoopFlowTest: BaseUITest {

    func testTrialToDraftToPendingVersion() async throws {
        let tabBar = TabBarPage(app: app)
        try tabBar.verify()

        // 1. Seed a recipe through the import flow.
        let importPage = try tabBar.goToImport().openTextEntry()
        _ = try importPage.typeRecipe("Sauce tomate : 400 g de tomates pelées, 1 gousse d'ail, 2 c. à soupe d'huile d'olive, basilic, sel. Mijoter 20 min.")
        let recipe = try importPage.analyze().verify().save()
        try recipe.verify()

        // 2. Record a trial for the fresh recipe via the round centre CTA
        //    (no pending "à tester" version yet).
        let capture = try recipe.recordTrial().verify()

        // 3. Record a trial with a remark → triggers an AI draft (the note itself
        //    no longer matters; the written remark is what asks for a draft).
        _ = try capture.pickStars(3)
        _ = try capture.typeRemarks("Coule trop vite, amertume sèche en finale.")
        try capture.save()

        // 4. Draft → validate the iteration.
        let draft = DraftPage(app: app)
        try draft.verify()
        try draft.validate()

        // 5. Back on the fiche, the pending v2 banner is now present.
        try recipe.verifyPendingVersion(2)
    }
}
