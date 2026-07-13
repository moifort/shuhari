import Apollo
import Foundation

enum RecipeAPI {
    // MARK: - Queries

    static func getRecipe(id: String) async throws -> Recipe {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShuhariGraphQL.RecipeQuery(id: id)
        )
        guard let recipe = data.recipe else { throw APIError.invalidResponse }
        return mapRecipe(recipe)
    }

    static func getTrial(id: String) async throws -> Trial {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShuhariGraphQL.TrialDetailQuery(id: id)
        )
        guard let trial = data.trial else { throw APIError.invalidResponse }
        return mapTrial(trial.fragments.trialFields)
    }

    // MARK: - Mutations

    static func promoteVersion(recipeId: String, versionNumber: Int) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.PromoteVersionMutation(recipeId: recipeId, versionNumber: versionNumber)
        )
    }

    static func deleteRecipe(id: String) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.DeleteRecipeMutation(id: id)
        )
    }

    static func updateRecipe(id: String, title: String?, subtitle: String?) async throws {
        let input = ShuhariGraphQL.UpdateRecipeInput(
            subtitle: GraphQLHelpers.graphQLNullable(subtitle),
            title: GraphQLHelpers.graphQLNullable(title)
        )
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShuhariGraphQL.UpdateRecipeMutation(id: id, input: input)
        )
    }
}

// MARK: - Mapping

func mapRecipe(_ r: ShuhariGraphQL.RecipeQuery.Data.Recipe) -> Recipe {
    Recipe(
        id: r.id,
        title: r.title,
        subtitle: r.subtitle,
        type: RecipeType(graphql: r.type),
        createdAt: GraphQLHelpers.parseISO8601(r.createdAt) ?? Date(),
        updatedAt: GraphQLHelpers.parseISO8601(r.updatedAt) ?? Date(),
        currentVersion: r.currentVersion.map { mapVersion($0.fragments.versionFields) },
        toTest: r.toTest.map { mapVersion($0.fragments.versionFields) },
        versions: r.versions.map { mapVersion($0.fragments.versionFields) },
        trials: r.trials.map { mapTrial($0.fragments.trialFields) },
        variations: r.variations.map { mapRef($0.fragments.recipeRefFields) },
        derivedFrom: r.derivedFrom.map { mapRef($0.fragments.recipeRefFields) },
        pendingProposal: r.pendingProposal.map { mapProposal($0.fragments.proposalFields) }
    )
}

func mapVersion(_ v: ShuhariGraphQL.VersionFields) -> RecipeVersion {
    RecipeVersion(
        number: v.number,
        change: v.change,
        why: v.why,
        originKind: VersionOriginKind(graphql: v.originKind),
        originDetail: v.originDetail,
        changedKeys: v.changedKeys,
        params: v.params.map { Param(key: $0.key, value: $0.value) },
        ingredients: (v.ingredients ?? []).map { Ingredient(name: $0.name, quantity: $0.quantity) },
        steps: v.steps,
        tmxSteps: v.tmxSteps.map { list in
            list.map { $0.map { TmxSettings(time: $0.time, temperature: $0.temperature, speed: $0.speed, reverse: $0.reverse ?? false) } }
        },
        averageNote: v.averageNote,
        trialCount: v.trialCount,
        createdAt: GraphQLHelpers.parseISO8601(v.createdAt) ?? Date()
    )
}

func mapTrial(_ t: ShuhariGraphQL.TrialFields) -> Trial {
    Trial(
        id: t.id,
        recipeId: t.recipeId,
        versionNumber: t.versionNumber,
        note: t.note,
        remarks: t.remarks,
        realParams: t.realParams.map { Param(key: $0.key, value: $0.value) },
        photoUrl: t.photoUrl,
        executedAt: GraphQLHelpers.parseISO8601(t.executedAt) ?? Date()
    )
}

func mapProposal(_ p: ShuhariGraphQL.ProposalFields) -> Proposal {
    Proposal(
        recipeId: p.recipeId,
        versionNumber: p.versionNumber,
        recommendation: ProposalRecommendation(graphql: p.recommendation),
        vars: p.vars.map { ProposalVar(key: $0.key, from: $0.from, to: $0.to) },
        rationale: p.rationale,
        queued: p.queued,
        variation: p.variation.map { VariationSuggestion(title: $0.title, description: $0.description) },
        createdAt: GraphQLHelpers.parseISO8601(p.createdAt) ?? Date()
    )
}

func mapRef(_ r: ShuhariGraphQL.RecipeRefFields) -> RecipeRef {
    RecipeRef(
        id: r.id,
        title: r.title,
        type: RecipeType(graphql: r.type),
        subtitle: r.subtitle,
        currentVersionNumber: r.currentVersion?.number,
        averageNote: r.currentVersion?.averageNote
    )
}
