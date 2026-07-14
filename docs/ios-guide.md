# iOS Development Guide

## Tech Stack

- **SwiftUI**, iOS 26.0 deployment target
- **Swift 6** with strict concurrency
- **GraphQL via Apollo iOS** (not REST) — typed operations generated from `shared/schema.graphql`
- **Firebase Auth + Sign in with Apple** (mono-user, but real auth)
- **Sentry** (`sentry-cocoa`, SPM) for error reporting
- Style: **Liquid Glass** — native iOS 26 components, no custom re-skins

Xcode project `ios/Shuhari.xcodeproj`, scheme `Shuhari`, bundle id `com.polyforms.shuhari.app`,
team `46C337T7YN`. The project uses `fileSystemSynchronizedGroups`, so new files are picked up
without editing the pbxproj.

## Project Structure

```
ios/
├── apollo-codegen-config.json          # Apollo codegen config (schemaNamespace: ShuhariGraphQL)
└── Shuhari/
    ├── ShuhariApp.swift                # @main; FirebaseApp.configure() in init(); DEBUG gallery branch
    ├── Shuhari.entitlements            # Sign in with Apple
    ├── GoogleService-Info.plist        # Firebase config
    ├── Generated/GraphQL/              # Apollo codegen output (do not edit)
    │   ├── Operations/{Queries,Mutations}/
    │   ├── Fragments/                  # VersionFields, RecipeRefFields, ProposalFields, TrialFields
    │   └── Schema/                     # CustomScalars (RecipeId, Note, …), Enums, Objects, InputObjects
    ├── Features/
    │   ├── Auth/  Home/  Recipe/  Proposal/  Execution/  Import/  Settings/
    │   └── {Feature}/
    │       ├── {Feature}Store.swift    # ViewModel (@MainActor @Observable) — or {Feature}ViewModel
    │       ├── {Feature}API.swift      # maps generated types → model structs
    │       ├── {Feature}Models.swift   # Sendable model structs
    │       ├── {Feature}View.swift     # coordinator (navigation, API, sheets)
    │       ├── GraphQL/*.graphql       # hand-written operations for this feature
    │       └── components/{pages,organisms,molecules}/
    └── Shared/
        ├── Components/                 # shared atoms (Chip, NoteBadge, ParamsGrid, …)
        ├── GraphQLClient.swift         # singleton ApolloClient
        ├── GraphQLHelpers.swift        # async fetch/perform bridges + nullable helpers
        ├── APIClient.swift             # base-URL resolver only
        ├── Theme.swift  DebugGallery.swift  PreviewFixtures.swift
        └── RecipeType+GraphQL.swift    # enum bridging generated ⇄ design enums
```

> **Layer naming is role-based, not uniform.** The *coordinator* is a `*View.swift` (owns
> navigation + API); *pure presentation* is a `*Page.swift`; the *ViewModel* is a `*Store` (Home
> and most features) or a `*ViewModel` (Recipe). Atoms live centrally in `Shared/Components/` —
> features have no per-feature `atoms/`. Some features (Proposal, Import) only have `pages/`.

## Data fetching — GraphQL, not REST

All transport goes through Apollo. `APIClient` is reduced to resolving the base URL; there is no
REST data layer in the app (`Shared/Services/` is empty).

### The client

`Shared/GraphQLClient.swift` — a singleton `ApolloClient` pointed at `<baseURL>/graphql`, with an
interceptor chain that injects the Firebase token and logs:

```swift
final class GraphQLClient: @unchecked Sendable {
    static let shared = GraphQLClient()
    let apollo: ApolloClient
    private init() {
        let url = APIClient.shared.baseURL.appendingPathComponent("graphql")
        let store = ApolloStore()
        let transport = RequestChainNetworkTransport(
            interceptorProvider: AuthenticatedInterceptorProvider(store: store),
            endpointURL: url)
        apollo = ApolloClient(networkTransport: transport, store: store)
    }
}

final class AuthenticatedInterceptorProvider: DefaultInterceptorProvider {
    override func interceptors<O: GraphQLOperation>(for operation: O) -> [any ApolloInterceptor] {
        var list = super.interceptors(for: operation)
        list.insert(FirebaseTokenInterceptor(), at: 0)   // Authorization: Bearer <ID token>
        list.append(GraphQLLoggingInterceptor())
        return list
    }
}
```

### The async helpers

`Shared/GraphQLHelpers.swift` bridges Apollo callbacks to `async`/`await`, surfaces GraphQL
errors as `APIError.graphQL`, and **fully disables the normalized cache**
(`cachePolicy: .fetchIgnoringCacheCompletely`, `publishResultToStore: false`):

```swift
let data = try await GraphQLHelpers.fetch(GraphQLClient.shared.apollo, query: ShuhariGraphQL.HomeQuery())
_    = try await GraphQLHelpers.perform(GraphQLClient.shared.apollo, mutation: ShuhariGraphQL.UpdateRecipeMutation(id: id, input: input))
```

It also provides `graphQLNullable(_:)` (wrap `T?` into `GraphQLNullable`, blank strings → `.none`)
and `parseISO8601(_:)` for the `DateTime` scalar.

### The feature API enum — the mapping boundary

Each feature exposes a caseless `enum {Feature}API` of static async functions that call the
generated operations and **map generated types → `Sendable` model structs**. Generated Apollo
types must never leak into views.

```swift
enum HomeAPI {
    static func getHome() async throws -> HomeData {
        let data = try await GraphQLHelpers.fetch(GraphQLClient.shared.apollo, query: ShuhariGraphQL.HomeQuery())
        let home = data.home
        return HomeData(
            toTest: home.toTest.compactMap { recipe in
                guard let version = recipe.toTest else { return nil }
                return HomeTestItem(id: recipe.id, title: recipe.title,
                                    type: RecipeType(graphql: recipe.type),
                                    versionNumber: version.number, change: version.change,
                                    why: version.why ?? version.originDetail)
            },
            library: home.library.map { LibraryRecipe(id: $0.id, title: $0.title, /* … */) },
            recentTrials: home.recentTrials.map { /* map to Trial */ })
    }
}
```

For mutations, build inputs with the nullable helper; enum bridging (generated
`GraphQLEnum<ShuhariGraphQL.RecipeType>` ⇄ the design `RecipeType`) is centralized in
`Shared/RecipeType+GraphQL.swift` via `init(graphql:)` / `.graphQLValue`.

## Feature Pattern

### ViewModel — `@MainActor @Observable`, single-flight

Use the Observation framework (`@Observable`), not `ObservableObject`. Guard against concurrent
loads with an `@ObservationIgnored` in-flight task.

```swift
@MainActor @Observable
final class HomeStore {
    var data: HomeData?
    var isLoading = false
    var error: String?
    @ObservationIgnored private var inFlight: Task<Void, Never>?

    func load() async {
        if let inFlight { return await inFlight.value }
        let task = Task {
            isLoading = true; error = nil
            do { data = try await HomeAPI.getHome() }
            catch { self.error = reportError(error) }   // captures to Sentry + returns the message
            isLoading = false
        }
        inFlight = task
        await task.value
        inFlight = nil
    }
}
```

### Coordinator (`*View.swift`) vs. Page (`*Page.swift`)

The **coordinator** owns the `NavigationStack`, sheets, `.task`/`.refreshable`, and reads the
store from the environment. The **page** is pure: data in, closures out — no networking, no
navigation state.

```swift
struct HomeView: View {                       // coordinator
    @Environment(HomeStore.self) private var store
    @State private var path = NavigationPath()
    var body: some View {
        NavigationStack(path: $path) {
            if let data = store.data {
                HomePage(data: data, onExecute: { … }, onSettings: { … })
            } else if let error = store.error { ContentUnavailableView(…) }
            else { HomePage(data: .placeholder, …).redacted(reason: .placeholder) }
        }
        .task { if store.data == nil { await store.load() } }
        .refreshable { await store.load() }
    }
}

struct HomePage: View {                        // pure presentation
    let data: HomeData
    let onExecute: (HomeTestItem) -> Void
    let onSettings: () -> Void
    var body: some View {
        List {
            ToTestSection(items: data.toTest, onExecute: onExecute)
            LibrarySection(data: data)
            RecentTrialsSection(trials: data.recentTrials, titleProvider: data.title(forRecipe:))
        }
    }
}
```

## Atomic Design

| Layer | Location | Receives | Examples |
|-------|----------|----------|----------|
| **Atoms** | `Shared/Components/` | Primitives | `Chip`, `NoteBadge`, `ParamsGrid`, `StepsList` |
| **Molecules** | `Features/{F}/components/molecules/` | Primitives | `TrialRow`, `LibraryRow`, `TestBanner` |
| **Organisms** | `Features/{F}/components/organisms/` | Primitives or a domain struct (mapping boundary) | `RecentTrialsSection`, `LibrarySection` |
| **Pages** | `Features/{F}/components/pages/` | Data + closures | `HomePage` |

Atoms in `Shared/Components/` are cross-feature. Promote a molecule used in 2+ features up to
`Shared/Components/`.

### Primitive-first leaf views

Leaf views receive only primitives — never the generated GraphQL types, and never full domain
model structs when they use a handful of fields.

**Allowed:** `String`, `Int`, `Int?`, `Double?`, `Bool`, `Date?`; simple enums without logic
(like `RecipeType`); closures. **Never:** generated Apollo types.

### Nested `Item` struct (5+ parameters)

When a component needs many parameters, define a nested `Item`. Example — `ParamsGrid`:

```swift
struct ParamsGrid: View {
    struct Item: Identifiable {
        let id = UUID()
        let key: String
        let value: String
        var highlighted: Bool = false
    }
    let items: [Item]
    var big: Bool = false
}
```

The mapping from model to `Item` happens at the page/organism level.

## Previews as a Storybook + DebugGallery

Every component below page level **must** preview without a running server, fed by
`Shared/PreviewFixtures.swift` (`Fixtures`).

```swift
#Preview("À tester") {
    HomePage(data: Fixtures.home, onExecute: { _ in }, onSettings: {})
}
```

`Shared/DebugGallery.swift` (wrapped in `#if DEBUG`) renders any page with fixtures and no
server/auth. `ShuhariApp` branches into it when the `gallery` UserDefault / `-gallery <screen>`
launch argument is set (screens: `home`, `recipe`, `recipe-tmx`, `history`, `trial`, `execute`,
`execute-tmx`, `capture`, `proposal`, `import-preview`, `root`).

## Error reporting — Sentry

`ShuhariApp.init()` calls `SentrySDK.start` (right after `FirebaseApp.configure()`) with a
hardcoded DSN — a Sentry DSN is public by design. A blank/placeholder DSN leaves the SDK inert
(same "no-op on empty DSN" behaviour as the backend plugin). `Shared/ErrorReporting.swift`'s
`reportError(_:)` does `SentrySDK.capture(error:)` and returns the display message; the 10+
call sites in ViewModels are unchanged.

## Auth — Firebase + Sign in with Apple

Wired in `Features/Auth/` plus `FirebaseApp.configure()` in `ShuhariApp.init()` (no `AppDelegate`):

- `AuthRoot.swift` — top gate: `LoginView` when signed out, else `ContentView`; injects
  `AuthSession` into the environment.
- `AuthSession.swift` — `@MainActor @Observable` wrapper over Firebase's
  `addStateDidChangeListener`; exposes `user` and `signOut()`.
- `LoginView.swift` — `SignInWithAppleButton`; exchanges the Apple identity token for a Firebase
  credential (`OAuthProvider.appleCredential`), then `Auth.auth().signIn`.
- `AppleNonce.swift` — nonce `random()` + `sha256()` (CryptoKit).
- `Shared/FirebaseTokenInterceptor.swift` — adds `Authorization: Bearer <ID token>` to every
  Apollo request.

## Model Types

Model structs are `Sendable` (Swift 6). They are what ViewModels and views consume — never the
generated types.

```swift
struct Trial: Identifiable, Sendable {
    let id: String
    let recipeId: String
    let versionNumber: Int
    let note: Int
    let remarks: String
    let realParams: [Param]
    let photoUrl: String?
    let executedAt: Date
}
```

## Apollo Codegen

Config: `ios/apollo-codegen-config.json`.

- `schemaNamespace: "ShuhariGraphQL"`
- schema source: `../shared/schema.graphql` (shared with the backend)
- operation search paths: `Shuhari/Features/<Feature>/GraphQL/*.graphql` (hand-written per feature)
- output: `Shuhari/Generated/GraphQL`, `moduleType: embeddedInTarget "Shuhari"`

Regenerate after the SDL changes:

```bash
bun run generate:graphql            # backend: regenerate shared/schema.graphql
cd ios && apollo-ios-cli generate   # iOS: regenerate Generated/GraphQL
```

## UI Testing — Page Object pattern

`ShuhariUITests/` holds `Tests/` (`ScreenshotTest`, `TrialLoopFlowTest`, `ImportFlowTest`,
`PromotionFlowTest`), `Pages/` (page objects), and `Support/`.

`BaseUITest` resets the DB before/after and launches with
`-serverURLDev http://localhost:3000 -serverMode dev -UITestPhoto`, adding
`XCUIElement.waitOrFail`/`tapOrFail`. Page objects are `@MainActor struct`s wrapping
`XCUIApplication`, keyed on accessibility identifiers, returning the next page for chaining:

```swift
@MainActor struct HomePage {
    let app: XCUIApplication
    func openRecipe(_ title: String) throws -> RecipeDetailPage { … }
    func openSettings() throws { try app.buttons["home-settings-button"].tapOrFail() }
}
```

`Support/TestAPIClient` is a small REST client used **only** against the test server's helper
endpoints (`/test/reset`, `/test/seed-recipe`) — production data flow stays 100% GraphQL.

## Build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/Shuhari.xcodeproj -scheme Shuhari \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' build
```

`DEVELOPER_DIR` is required because `xcode-select` points at CommandLineTools.
