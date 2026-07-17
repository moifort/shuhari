# Shuhari

守破離 — *Shu* (suivre la règle), *Ha* (la casser), *Ri* (la transcender).

Un carnet d'expérimentation culinaire qui applique une boucle scientifique à la
cuisine : on importe une recette, on l'exécute, on note l'essai, puis l'IA
propose l'itération suivante. Chaque recette progresse version après version
jusqu'à trouver la meilleure.

## Le concept

Deux types d'expérimentations culinaires : **plat** et **tmx** (Thermomix) — le
café et le cocktail reviendront plus tard, chacun dans son propre domaine. Chaque
recette porte une **catégorie de plat** (entrée, plat, dessert, soupe, sauce,
boulangerie). La boucle est toujours la même :

1. **Importer** une recette depuis une photo (prise sur le vif avec l'appareil
   photo ou choisie dans la bibliothèque), un lien ou du texte — l'IA (Gemini)
   en extrait les **ingrédients** et les **étapes**, et **détecte la catégorie
   de plat**. Pour une recette Thermomix, elle relève aussi les réglages de
   chaque étape (temps, température, vitesse, sens inverse), affichés en badges
   dédiés.
2. **Exécuter** la version courante — ses ingrédients et ses étapes — et
   **noter** l'essai de **1 à 5 étoiles** (remarques et photos à l'appui).
3. **Itérer** — l'IA propose la version suivante sous forme de **brouillon
   complet** (résumé du changement, justification, ingrédients et étapes), que
   l'on peut **modifier avant de l'accepter**.
4. **Valider** la proposition en **itération** (nouvelle version de la même
   recette) ou en **variation** (nouvelle recette dérivée, avec sa propre
   lignée).
5. **Promouvoir** — dès qu'un essai atteint **4 étoiles ou plus**, la version
   testée devient la nouvelle référence.

Le carnet rassemble toutes les recettes dans une **bibliothèque paginée**,
triable par **catégorie de plat** ou par **dernière modification**, avec un
filtre Plat / Thermomix.

Application mono-utilisateur, mais avec une vraie authentification Firebase +
Sign in with Apple.

## Architecture

| Couche   | Stack                                                                            |
| -------- | -------------------------------------------------------------------------------- |
| iOS      | SwiftUI, Swift 6, iOS 26, MVVM `@Observable`, Apollo iOS, style Liquid Glass     |
| Backend  | Bun + Nitro 2.13 (Firebase Cloud Functions Gen 2, nodejs22, europe-west3)        |
| API      | Apollo Server 5 + Pothos 4 — endpoint GraphQL unique `POST /graphql`             |
| Stockage | Firestore natif (firebase-admin), isolé par `userId`                             |
| IA       | Gemini 2.5 Flash (import de recettes + propositions d'itérations)                |
| Infra    | Terraform sur GCP (projet `shuhari-polyforms`), déploiement CI via WIF           |

Le backend suit une architecture **DDD/CQRS** stricte. Domaines dans
`server/domain/` : `recipe` (la recette et sa lignée de versions — chaque
version porte son essai noté), `draft` (les brouillons d'itération de l'IA,
éphémères), `home` (l'agrégation d'accueil), `portability` (export/import des
données), `changelog`. Les concerns transverses sont dans `server/system/`
(`ai`, `firebase`, `config`, `migration`, `request-cache`).

## Documentation

Les guides techniques détaillés vivent dans `docs/` (en anglais, comme le reste du code) :

| Guide | Ce qu'il couvre |
| ----- | --------------- |
| [Architecture](docs/architecture.md) | Organisation du backend : DDD/CQRS, Firestore, couches, plomberie GraphQL |
| [Domain Guide](docs/domain-guide.md) | Ajouter un domaine pas à pas (types, repository, command/query, GraphQL, tests) |
| [GraphQL Patterns](docs/graphql-patterns.md) | Schéma Pothos par domaine, scalars branded, loaders anti-N+1, mapping des erreurs |
| [Branded Types](docs/branded-types.md) | Types nominaux `ts-brand` + validation Zod dans `primitives.ts` |
| [Code Style](docs/code-style.md) | Conventions TypeScript/Swift, règles imposées par le test d'architecture |
| [Error Handling](docs/error-handling.md) | Sentinelles string, `match().exhaustive()`, `throw` pour les états impossibles |
| [Migrations](docs/migrations.md) | Migrations Firestore forward-only via `POST /admin/migrate` |
| [iOS Guide](docs/ios-guide.md) | App SwiftUI : GraphQL/Apollo, Firebase Auth, design atomique, previews |
| [Git Workflow](docs/git-workflow.md) | Règles de commits et de push : une tâche = un commit, rollback, remodelage au push |
| [README Guide](docs/readme-guide.md) | Écrire et maintenir ce README : structure, clés, liens vers les guides |

Voir aussi [docs/apple-sign-in.md](docs/apple-sign-in.md) pour la configuration Sign in with Apple.

## Développement local

```bash
cp .env.example .env   # renseigner les clés
bun install
bun run prepare        # generate:assets + nitro prepare
bun run dev            # http://localhost:3000 — GraphQL sur POST /graphql
```

Avec la suite d'émulateurs Firebase (Auth + Firestore) :

```bash
firebase emulators:start --only auth,firestore,functions
```

Variables d'environnement (`.env`) :

```
NITRO_GOOGLE_API_KEY=...   # clé Gemini (obligatoire pour l'IA)
NITRO_ADMIN_TOKEN=...      # protège POST /admin/migrate
NITRO_SENTRY_DSN=          # optionnel — reporting d'erreurs Sentry
```

### Commandes utiles

```bash
bun tsc --noEmit           # typecheck backend
bun test                   # tests unitaires (*.unit.test.ts, bun:test)
bun run test:coverage      # couverture
bun run lint               # Biome (lint + format) ; --fix : bun run lint:fix
bun run generate:graphql   # régénère shared/schema.graphql
```

## Infrastructure

Toute la stack GCP — projet, Firebase, Firestore (règles + index), Identity
Platform avec Sign in with Apple, Cloud Function Gen 2, secrets, enregistrement
de l'app iOS — est provisionnée par Terraform.

```bash
bun run bootstrap   # provisionne l'infra de bout en bout
bun run infra:plan  # diff Terraform sans appliquer
bun run infra:apply # applique le plan
bun run destroy     # supprime les ressources
```

Le bootstrap construit le bundle Nitro (`nitro build`, preset firebase), lance
`terraform apply`, puis déclenche `POST /admin/migrate` pour appliquer les
migrations Firestore. Les déploiements suivants se font en poussant sur `main`
(GitHub Actions, authentification par Workload Identity Federation).

> `terraform` est téléchargé automatiquement (version épinglée) dans
> `infra/.bin/` via `scripts/tf` au premier `infra:*` / `bootstrap`.

## Prérequis

- **Bun** (jamais `npm`/`npx`)
- **Xcode 26** (SDK iOS 26) pour l'app
- `gcloud` authentifié en **Application Default Credentials** :
  `gcloud auth application-default login`
- Un compte Apple Developer (Service ID + Sign in with Apple + clé `.p8`) et un
  compte de facturation GCP pour le provisioning de l'infra

## App iOS

1. Ouvrir `ios/Shuhari.xcodeproj` dans Xcode.
2. Après `bun run bootstrap`, glisser le `GoogleService-Info.plist` généré dans
   la target `Shuhari`.
3. Régénérer les opérations GraphQL typées : depuis `ios/`, lancer
   `apollo-ios-cli generate` (à partir de `shared/schema.graphql`).
4. Build & run sur le simulateur iPhone 17 (iOS 26.2).

Bundle : `com.polyforms.shuhari.app` · Team : `46C337T7YN`.
