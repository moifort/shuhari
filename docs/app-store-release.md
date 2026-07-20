# App Store Release

A release is a git tag. `.github/workflows/release.yml` does the rest: it guards, shoots the
store panels, archives, uploads, submits for review and publishes on approval.

## Releasing

1. Write the release notes in English under `## Unreleased` in `CHANGELOG.md`, then the French
   translation under `## Unreleased` in `CHANGELOG.fr.md`.
2. Rename `## Unreleased` to `## <version> (<YYYY.MM.DD>)` in **both** files. There is no CI
   date stamp; versioning is manual, and the pipeline refuses to run while an `## Unreleased`
   section remains — the app would otherwise display "Unreleased" as a version title.
3. Set `MARKETING_VERSION` in `ios/Shuhari.xcodeproj/project.pbxproj` to the same version. The
   pipeline refuses a tag that disagrees with it.
4. Push `main`. The Deploy workflow rebuilds `server/system/changelog-content.ts` from
   `CHANGELOG.fr.md`; **without this the in-app changelog stays stale**.
5. Tag and push:
   ```bash
   git tag v1.0 && git push origin v1.0
   ```

`CURRENT_PROJECT_VERSION` is not edited by hand: the workflow passes the run number, which only
ever grows. App Store Connect rejects a build number it has already seen.

## What the listing is made of

The whole listing lives in `fastlane/metadata/` and is overwritten on every release: texts,
keywords, categories, price, age rating, screenshots. Editing it in App Store Connect is
pointless — the next release wipes it. Change the files, commit, tag.

The screenshots are shot on an `iPhone 17 Pro Max` simulator (1320×2868, the 6.9-inch size the
App Store derives every other iPhone size from) and composed by `scripts/screenshots/compose.ts`
from the CSS template in `scripts/screenshots/panel.ts`. The captions live in
`scripts/screenshots/panels.json`.

Two traps the pipeline already works around, worth knowing before touching it:

- The simulator build is made in **Debug**. `DebugGallery` sits behind `#if DEBUG`; a Release
  build ignores the `-gallery` argument and every capture returns the same screen.
- Each capture **terminates the app before relaunching it**. `simctl launch` on a running app
  foregrounds it without re-reading its arguments, which silently returns the previous screen.

## Signing

No certificate is stored anywhere. The workflow authenticates with an App Store Connect API key
(`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`) and passes `-allowProvisioningUpdates`, so Xcode
fetches the distribution certificate and profile itself.

## Xcode version

The workflow selects the newest Xcode on the runner. Building with anything but the latest final
Xcode triggers **ITMS-90111** (Unsupported SDK or Xcode version) on upload.

## Archiving from the dev Mac instead

Only useful when the pipeline is unavailable. If the dev Mac runs a **beta macOS**, archives get
a prerelease `BuildMachineOSBuild` stamp that App Store validation rejects, also with ITMS-90111.
After archiving, patch it to the latest **public** macOS build number *before* `-exportArchive`
(export re-signs, so the patch survives):

```bash
plutil -replace BuildMachineOSBuild -string '<latest public macOS build>' \
  build/Shuhari.xcarchive/Products/Applications/Shuhari.app/Info.plist
```

Look up the current public macOS build at https://developer.apple.com/news/releases. Verify
`DTXcodeBuild`/`DTSDKBuild` are untouched, then export. CI runners never run a beta macOS, so
this never applies there.

## The pages the App Store demands

A privacy URL and a support URL are mandatory. Both are served by GitHub Pages from
`docs/pages/`, deployed by `.github/workflows/pages.yml`. **The privacy page and the App Store
Connect privacy questionnaire must agree** — a divergence is a common rejection.

## Still missing before the first submission

**In-app account deletion.** Guideline 5.1.1(v) requires any app that creates accounts to let
them be deleted from within the app. Shuhari signs cooks in with Apple but exposes no such
action: the schema stops at `deleteRecipe` and `deleteVersion`, and Settings only offers import
and export. Until a `deleteAccount` mutation exists — purging `recipes`, `recipe-versions`,
`ai-quotas` and `entitlements`, revoking the Apple token and removing the Firebase Auth user —
the first submission is very likely to be rejected.
