# Writing the Project README

Guide for writing and maintaining the top-level `README.md`. The README is the first thing someone
reads — it should answer "what is this, how do I install it, how do I run it" without requiring prior
knowledge of the codebase. Deep architecture belongs in `docs/`, not here.

## Principles

1. **Explain what things do, not how they're built.** "A notebook to perfect your recipes" — not
   "A Nitro-based DDD backend with native Firestore storage and branded types".
2. **Name every file explicitly.** "Edit `.env`" — not "edit the environment file".
3. **Explain why before how.** "The admin token protects the migration endpoint. To create one: …"
   — not just "Set `NITRO_ADMIN_TOKEN` in `.env`".
4. **Number every step.** A reader should follow the README top to bottom without jumping around.
5. **No jargon unless the reader needs it.** Skip DDD, branded types, discriminated unions,
   architectural layers. These belong in `docs/`.
6. **Keep it in English.** Consistent with code, commit messages, and the rest of the documentation.

## Structure

Follow this order. Skip a section only if it genuinely doesn't apply.

### 1. Title + one-line description

The name of the project and one sentence that says what it does for the user.

```md
# Shuhari

A culinary experimentation notebook — import a recipe, run it, rate the trial, and let the AI
propose the next iteration.
```

Not what it's built with. Not the architecture. What it does.

### 2. What the project does

A short list (3-6 bullets) of what the project contains, from a user's perspective. Each bullet =
one capability.

```md
## What's in the box

- A **backend server** that stores your recipes and their version lineage, each version carrying its own essai
- **AI import & iteration** — paste a recipe to import it, get a suggested next version to try
- An **iOS app** to browse recipes, cook a version, rate the essai, and open the best-rated one
- **Error monitoring** with Sentry so you know when something breaks (optional)
```

Rules:
- Lead with the user benefit, not the technology.
- Put "(optional)" next to things that aren't required.
- Don't list internal implementation details (migrations, middleware, plugins).

### 3. Prerequisites

A table with three columns: what to install, what it does, how to install it.

```md
## Prerequisites

| Tool | What it does | Install |
|------|-------------|---------|
| [Bun](https://bun.sh/) | Runs the backend server | `curl -fsSL https://bun.sh/install \| bash` |
| [Xcode](https://developer.apple.com/xcode/) | Builds the iOS app | Mac App Store |
```

Only list things the reader installs themselves. Don't list transitive dependencies (TypeScript,
Swift packages — handled automatically).

### 4. Installation

Walk through every step from "I just cloned the repo" to "the project is ready": install deps, copy
`.env.example` to `.env`, copy `ios/Shuhari/Shared/Secrets.swift.example` to `Secrets.swift`, set up
Firebase credentials, etc. Number each step and keep code blocks copy-pasteable.

### 5. Setting up keys

One subsection per key. Each answers three questions: **what it does** (one sentence, no jargon),
**how to get it** (exact steps), **where to put it** (table with file path + variable name).

```md
### Gemini API key

**What it does:** powers recipe import and AI iteration proposals (Gemini 2.5 Flash).

**How to get it:** create a key in Google AI Studio (https://aistudio.google.com/apikey).

**Where to put it:**

| File | Variable |
|------|----------|
| `.env` | `NITRO_GOOGLE_API_KEY=your-key-here` |
```

Shuhari's keys: `NITRO_GOOGLE_API_KEY` (required — the AI), `NITRO_ADMIN_TOKEN` (required — gates
`POST /admin/migrate`), `NITRO_SENTRY_DSN` (optional). The standard GraphQL API authenticates via
the **Firebase ID token**, so the app needs no static API token to run.

Rules:
- Mark optional keys as optional.
- If a key comes from an external service (Firebase, Google AI Studio, Sentry), link to it and give
  the exact navigation path to find the value.
- Show the actual file paths from the project, not generic ones.
- In production, secrets live in GCP Secret Manager (project `shuhari-polyforms`), provisioned by
  the infra — never commit them.

### 6. Running the project

Two subsections: backend + iOS. Each should be copy-pasteable.

```md
## Running the project

### Start the backend

\```bash
bun run dev
\```

The server starts at `http://localhost:3000`. GraphQL (and the Apollo Sandbox in dev) is at
`/graphql`.

### Run the iOS app

1. Open the Xcode project: `open ios/Shuhari.xcodeproj`
2. Set your Development Team in Signing & Capabilities
3. Pick a simulator and hit Run
```

Include a way to verify it works (a GraphQL query in the Sandbox, an expected screen, etc.).

### 7. Deployment

How to build and deploy. Document only what is actually set up (Terraform on GCP / Firebase Cloud
Functions, the `POST /admin/migrate` deploy step) — don't document hypothetical options.

### 8. Documentation links

A table linking to the guides in `docs/`. One line per guide, with a plain-language description of
what it covers.

```md
## Documentation

| Guide | What it covers |
|-------|---------------|
| [Architecture](docs/architecture.md) | How the backend is organized |
| [Domain guide](docs/domain-guide.md) | How to add a new domain |
| [GraphQL patterns](docs/graphql-patterns.md) | How the GraphQL layer is built |
| [iOS guide](docs/ios-guide.md) | How to add screens to the iOS app |
| [Git workflow](docs/git-workflow.md) | How commits and pushes are handled |
```

Describe what the reader will learn, not the technical content. "How to add screens to the iOS app"
— not "SwiftUI feature structure with atomic design and MVVM ViewModels".

## Checklist

- [ ] A developer who doesn't know the project can install and run it by following the README alone
- [ ] Every file path mentioned actually exists in the project
- [ ] Every key/secret has: what it does, how to get it, where to put it
- [ ] No section assumes knowledge of the codebase internals
- [ ] No unexplained acronyms or framework-specific terms
- [ ] Code blocks are copy-pasteable (no placeholder that would fail if pasted, except obvious ones
      like `your-key-here`)
```
