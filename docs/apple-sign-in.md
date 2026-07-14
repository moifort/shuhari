# Apple Sign-In Setup

How **Sign in with Apple** is wired for the Shuhari iOS app (Firebase Auth / Identity
Platform). The infra is already in place and **conditionally activates** as soon as the values
below are supplied — the work is done in the **Apple Developer portal**, then three values plus
one file are fed back into the repo. The iOS side needs no changes.

## Fixed constants

These are already set across the project — do not change them.

| Item | Value |
| ---- | ----- |
| Apple Team ID | `46C337T7YN` |
| App ID (bundle id) | `com.polyforms.shuhari.app` |
| Services ID | `com.polyforms.shuhari.signin` |
| Firebase / GCP project | `shuhari-polyforms` |
| Firebase auth domain | `shuhari-polyforms.firebaseapp.com` |
| OAuth return URL | `https://shuhari-polyforms.firebaseapp.com/__/auth/handler` |

## Apple Developer portal

In [developer.apple.com/account](https://developer.apple.com/account) under Team `46C337T7YN`:

1. **App ID** — Certificates, Identifiers & Profiles → Identifiers → App IDs.
   - Ensure the App ID `com.polyforms.shuhari.app` exists (create it as type *App* otherwise).
   - Enable the **Sign In with Apple** capability (*Enable as a primary App ID*), then save.

2. **Services ID** — Identifiers → (filter *Services IDs*) → +.
   - Identifier `com.polyforms.shuhari.signin`, description `Shuhari Sign In`.
   - Check **Sign In with Apple**, then *Configure*:
     - **Primary App ID**: `com.polyforms.shuhari.app`
     - **Domains and Subdomains**: `shuhari-polyforms.firebaseapp.com`
     - **Return URLs**: `https://shuhari-polyforms.firebaseapp.com/__/auth/handler`
   - Save / continue / register.

3. **Sign in with Apple key** — Keys → +.
   - Name `Shuhari Sign In Key`.
   - Check **Sign In with Apple**, *Configure* → Primary App ID `com.polyforms.shuhari.app`.
   - *Continue* → *Register* → **download the `.p8` file** (⚠️ downloadable **only once**).
   - Note the 10-character **Key ID** shown on the key's page.

## Deliverables

From the steps above you end up with:

1. **Services ID** — `com.polyforms.shuhari.signin` (created and configured).
2. **Key ID** — the 10-character identifier of the key.
3. **`.p8` file** — the downloaded `AuthKey_XXXXXXXXXX.p8`.
4. **Team ID** — `46C337T7YN` (already known).

## Repo wiring

Once the deliverables are in hand:

1. Drop the `.p8` at `infra/apple.p8`.
2. In `infra/terraform.tfvars`: set `apple_key_id = "<KEY_ID>"` (the other Apple fields are
   already correct).
3. GitHub secrets (repo `moifort/shuhari`):
   - `APPLE_TEAM_ID` = `46C337T7YN`
   - `APPLE_SERVICES_ID` = `com.polyforms.shuhari.signin`
   - `APPLE_KEY_ID` = `<KEY_ID>`
   - `APPLE_PRIVATE_KEY_P8` = the full text contents of the `.p8`
4. `terraform apply` (or a push to `main`) enables the Apple provider in Identity Platform —
   `auth.tf` creates it automatically as soon as `apple_key_id` is set.

## iOS app

Nothing to do: the `com.apple.developer.applesignin` entitlement and the
`SignInWithAppleButton → OAuthProvider.appleCredential` flow are already in place.
