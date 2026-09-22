import Apollo
import Foundation

enum RecipeAPI {
    // MARK: - Queries

    static func getRecipe(id: String) async throws -> Recipe {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShuhariGraphQL.RecipeQuery(id: id)
        )
        guard let recipe = data.recipe, let mapped = mapRecipe(recipe) else {
            throw APIError.invalidResponse
        }
        return mapped
    }

    /// A recipe as a link shows it — its name and the shopping list of its best
    /// version, at its own weight. What the link sheet's weight step reads, instead of
    /// the whole recipe sheet.
    static func linkedRecipe(id: String) async throws -> LinkedRecipe {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShuhariGraphQL.LinkedRecipeQuery(id: id)
        )
        guard let linked = mapLinkedRecipe(data.recipe?.fragments.linkedRecipeFields, scale: 1)
        else { throw APIError.invalidResponse }
        return linked
    }

    // MARK: - Mutations

    /// Create a recipe and its v1 in one go. Returns the new recipe's id. Two ways in:
    /// a confirmed import preview, and a proposal saved as a recipe of its own rather
    /// than as the next version of the one it was proposed for.
    static func createRecipe(
        title: String,
        type: RecipeType,
        category: DishCategory,
        method: BrewMethod? = nil,
        content: VersionContent,
        tips: [String] = [],
        sourceLabel: String?
    ) async throws -> String {
        let input = ShuhariGraphQL.CreateRecipeInput(
            category: category.graphQLValue,
            content: GraphQLHelpers.versionContentInput(content),
            method: GraphQLHelpers.graphQLNullable(method?.graphQLValue),
            sourceLabel: GraphQLHelpers.graphQLNullable(sourceLabel),
            tips: tips,
            title: title,
            type: type.graphQLValue
        )
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.CreateRecipeMutation(input: input)
        )
        return data.createRecipe.id
    }

    /// Copy one version into a recipe of its own — the variant that has drifted too
    /// far to be one more iteration. The new recipe keeps the type, the course or the
    /// brew method and the cautions of the one copied, and its v1 carries that
    /// version's content, tips and rating. Returns the new recipe's id.
    static func copyVersion(recipeId: String, number: Int, title: String) async throws -> String {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.CopyVersionMutation(
                recipeId: recipeId,
                number: number,
                title: title
            )
        )
        return data.copyVersion.id
    }

    static func deleteRecipe(id: String) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.DeleteRecipeMutation(id: id)
        )
    }

    /// Delete one version from the lineage; the versions built on it are re-based
    /// onto the one it iterated on, its number is never reused.
    static func deleteVersion(recipeId: String, number: Int) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.DeleteVersionMutation(recipeId: recipeId, number: number)
        )
    }

    /// Heart one version, or take the heart off it. The recipe leads its course in
    /// the library as soon as any of its versions is hearted.
    static func updateFavorite(id: String, versionNumber: Int, favorite: Bool) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.UpdateFavoriteMutation(
                recipeId: id,
                versionNumber: versionNumber,
                favorite: favorite
            )
        )
    }

    /// Say that this recipe is made of another one, at the weight it takes of it. No
    /// version created — saying what a recipe is made of is not cooking it. Linking a
    /// recipe already linked rewrites its weight, which is how it is corrected.
    static func linkComponent(recipeId: String, component: String, scale: Double) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.LinkComponentMutation(
                recipeId: recipeId,
                component: component,
                scale: scale
            )
        )
    }

    /// Let go of one linked recipe. The recipe unlinked lives on, untouched.
    static func unlinkComponent(recipeId: String, component: String) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.UnlinkComponentMutation(
                recipeId: recipeId,
                component: component
            )
        )
    }

    /// What each free-text coffee field suggests: the values this cook has already
    /// typed, most recent first. One keyed document read, whatever the library size.
    static func coffeeVocabulary() async throws -> CoffeeVocabulary {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShuhariGraphQL.CoffeeVocabularyQuery()
        )
        let vocabulary = data.coffeeVocabulary
        return CoffeeVocabulary(
            beanNames: vocabulary.beanNames,
            countries: vocabulary.countries,
            producers: vocabulary.producers,
            waterKinds: vocabulary.waterKinds,
            milkKinds: vocabulary.milkKinds,
            machines: vocabulary.machines,
            profiles: vocabulary.profiles,
            grinders: vocabulary.grinders
        )
    }

    /// Write back a corrected recipe sheet: what the cook moved in the edit sheet,
    /// and nothing else — the aggregate's title, course, method and tags, and the
    /// displayed version's note, content, oven, cautions and tips — in one
    /// `correctVersion` call, saved whole or not at all. A field left untouched is
    /// left out, and a sheet closed on nothing moved sends nothing. None of it
    /// creates a version: correcting what the recipe always said is not iterating on it.
    static func correct(
        recipeId: String,
        versionNumber: Int,
        from: RecipeDraft,
        to: RecipeDraft
    ) async throws {
        let retagged = to.tags.tags != from.tags.tags
        let retouched = to.title != from.title || to.category != from.category
            || to.method != from.method || retagged
        // Taking a note back is not a gesture the server has: an emptied rating
        // leaves the one already given.
        let rating = to.rating.flatMap { $0 != from.rating ? $0 : nil }
        let ingredients = to.ingredients.ingredients != from.ingredients.ingredients
        let miseEnPlace = to.miseEnPlace.lines != from.miseEnPlace.lines
        let steps = to.steps.steps != from.steps.steps
        let oven = to.oven.profile != from.oven.profile
        let parameters = to.coffee.flatMap {
            $0.parameters != from.coffee?.parameters ? $0.parameters : nil
        }
        let warnings = to.warnings.lines != from.warnings.lines
        let tips = to.tips.lines != from.tips.lines
        guard retouched || rating != nil || ingredients || miseEnPlace || steps || oven
            || parameters != nil || warnings || tips
        else { return }

        let input = ShuhariGraphQL.CorrectionInput(
            coffeeParameters: GraphQLHelpers.graphQLNullable(
                parameters.map(GraphQLHelpers.coffeeParametersInput)
            ),
            ingredients: ingredients
                ? .some(to.ingredients.ingredients.map {
                    ShuhariGraphQL.IngredientInput(name: $0.name, quantity: $0.quantity)
                })
                : .none,
            miseEnPlace: miseEnPlace ? .some(to.miseEnPlace.lines) : .none,
            // `null` says the dish never bakes; left out, the oven stays as it was.
            oven: oven ? GraphQLHelpers.ovenProfileInput(to.oven.profile) : .none,
            rating: GraphQLHelpers.graphQLNullable(rating),
            recipe: retouched
                ? .some(ShuhariGraphQL.UpdateRecipeInput(
                    category: GraphQLHelpers.graphQLNullable(to.category.graphQLValue),
                    method: GraphQLHelpers.graphQLNullable(to.method?.graphQLValue),
                    // The complete list or nothing: untouched tags are not rewritten.
                    tags: retagged
                        ? .some(to.tags.tags.map {
                            ShuhariGraphQL.TagInput(
                                icon: GraphQLHelpers.graphQLNullable($0.icon?.graphQLValue),
                                label: $0.label
                            )
                        })
                        : .none,
                    title: .some(to.title)
                ))
                : .none,
            // The machine settings ride along and the server keeps them only on a
            // Thermomix version; a plain step sends none rather than an empty object.
            steps: steps
                ? .some(to.steps.steps.map { step in
                    ShuhariGraphQL.VersionStepInput(
                        settings: step.settings.isEmpty
                            ? .null
                            : .some(GraphQLHelpers.thermomixSettingsInput(step.settings)),
                        text: step.text
                    )
                })
                : .none,
            tips: tips ? .some(to.tips.lines) : .none,
            warnings: warnings ? .some(to.warnings.lines) : .none
        )
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.CorrectVersionMutation(
                recipeId: recipeId,
                versionNumber: versionNumber,
                input: input
            )
        )
    }
}

// MARK: - Mapping

/// Nil when the version to open is missing from the lineage — a response the server
/// never sends, since it picks that version out of the very same list.
func mapRecipe(_ r: ShuhariGraphQL.RecipeQuery.Data.Recipe) -> Recipe? {
    let versions = r.versions.map { mapVersion($0.fragments.versionFields) }
    guard let versionToOpen = versions.first(where: { $0.number == r.versionToOpen.number }) else {
        return nil
    }
    return Recipe(
        id: r.id,
        title: r.title,
        type: RecipeType(graphql: r.type),
        category: DishCategory(graphql: r.category),
        method: BrewMethod(graphql: r.method),
        tags: r.tags.map { Tag(label: $0.label, icon: TagIcon(graphql: $0.icon)) },
        favorite: r.favorite,
        versions: versions,
        bestRating: r.bestRating,
        versionToOpen: versionToOpen,
        components: r.components.compactMap {
            mapLinkedRecipe($0.recipe?.fragments.linkedRecipeFields, scale: $0.scale)
        },
        usedBy: r.usedBy.map { UsingRecipe(id: $0.id, title: $0.title, rating: $0.bestRating) }
    )
}

func mapVersion(_ v: ShuhariGraphQL.VersionFields) -> RecipeVersion {
    RecipeVersion(
        number: v.number,
        restDays: v.restDays,
        basedOn: v.basedOn,
        change: v.change,
        why: v.why,
        originKind: VersionOriginKind(graphql: v.originKind),
        originDetail: v.originDetail,
        content: mapVersionContent(v.content.fragments.versionContentFields),
        tips: v.tips,
        warnings: v.warnings,
        favorite: v.favorite,
        recipeId: v.recipeId,
        toTest: v.toTest,
        rating: v.rating,
        remarks: v.remarks,
        executedAt: v.executedAt.flatMap { GraphQLHelpers.parseISO8601($0) },
        photoUrl: v.photoUrl,
        createdAt: GraphQLHelpers.parseISO8601(v.createdAt) ?? Date(),
        updatedAt: GraphQLHelpers.parseISO8601(v.updatedAt) ?? Date()
    )
}

func mapProposal(_ d: ShuhariGraphQL.ProposalFields) -> Proposal {
    Proposal(
        basedOn: d.basedOn,
        changeSummary: d.changeSummary,
        rationale: d.rationale,
        content: mapVersionContent(d.content.fragments.versionContentFields),
        tips: d.tips
    )
}

/// The oven profile a cooked version bakes at → the Swift `OvenProfile`. nil stays
/// nil: a dish that never goes in the oven has no profile, not an empty one.
func mapOvenProfile(_ oven: ShuhariGraphQL.OvenProfileFields?) -> OvenProfile? {
    guard let oven else { return nil }
    return OvenProfile(
        program: OvenProgram(graphql: oven.program),
        assisted: oven.assisted,
        temperature: oven.temperature,
        duration: oven.duration,
        core: oven.core
    )
}

/// One link → the flat `LinkedRecipe` the sheet's top section lists. Reads the linked
/// recipe's `versionToOpen`, which is derived server-side: the sheet always shows its
/// best attempt, never a version it pinned down. A link whose recipe has been deleted
/// resolves to nothing and simply drops out of the list.
func mapLinkedRecipe(_ linked: ShuhariGraphQL.LinkedRecipeFields?, scale: Double) -> LinkedRecipe? {
    guard let linked else { return nil }
    let content = linked.versionToOpen.content
    let ingredients =
        content.asDishContent?.ingredients.map { Ingredient(name: $0.name, quantity: $0.quantity) }
        ?? content.asThermomixContent?.ingredients.map {
            Ingredient(name: $0.name, quantity: $0.quantity)
        }
        ?? []
    return LinkedRecipe(
        id: linked.id,
        title: linked.title,
        rating: linked.bestRating,
        scale: scale,
        ingredients: ingredients
    )
}

/// The version-body union → the Swift `VersionContent`. An unknown `__typename`
/// (a content type the app doesn't know yet) maps to an empty dish, matching the
/// lenient unknown-enum style in `RecipeType+GraphQL.swift`.
func mapVersionContent(_ c: ShuhariGraphQL.VersionContentFields) -> VersionContent {
    if let dish = c.asDishContent {
        return .dish(
            ingredients: dish.ingredients.map { Ingredient(name: $0.name, quantity: $0.quantity) },
            miseEnPlace: dish.miseEnPlace,
            steps: dish.dishSteps,
            oven: mapOvenProfile(dish.oven?.fragments.ovenProfileFields)
        )
    }
    if let thermomix = c.asThermomixContent {
        return .thermomix(
            ingredients: thermomix.ingredients.map {
                Ingredient(name: $0.name, quantity: $0.quantity)
            },
            miseEnPlace: thermomix.miseEnPlace,
            steps: thermomix.thermomixSteps.map { step in
                ThermomixStep(
                    text: step.text,
                    settings: ThermomixSettings(
                        time: step.settings.time,
                        temperature: step.settings.temperature,
                        speed: step.settings.speed,
                        reverse: step.settings.reverse ?? false
                    )
                )
            },
            oven: mapOvenProfile(thermomix.oven?.fragments.ovenProfileFields)
        )
    }
    if let coffee = c.asCoffeeContent {
        return .coffee(
            parameters: CoffeeParameters(
                beans: CoffeeBeans(
                    name: coffee.beans.name,
                    country: coffee.beans.country,
                    producer: coffee.beans.producer,
                    roastedOn: coffee.beans.roastedOn.flatMap { GraphQLHelpers.parseISO8601($0) },
                    dose: coffee.beans.dose
                ),
                water: CoffeeWaterSpec(
                    kind: coffee.water.kind,
                    amount: coffee.water.amount,
                    temperature: coffee.water.temperature
                ),
                extraction: CoffeeExtraction(
                    grind: coffee.extraction.grind,
                    time: coffee.extraction.time,
                    cupYield: coffee.extraction.yield
                ),
                // A nil block is a drink with no milk at all — not an empty one.
                milk: coffee.milk.map {
                    CoffeeMilk(kind: $0.kind, amount: $0.amount, temperature: $0.temperature)
                },
                gear: CoffeeGear(
                    machine: coffee.gear.machine,
                    grinder: coffee.gear.grinder,
                    profile: coffee.gear.profile
                )
            )
        )
    }
    return .dish(ingredients: [], steps: [])
}
