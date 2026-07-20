# App Store Release

How a build reaches the App Store. The changelog is written **here**, at release time — never at
push time (see [git-workflow.md](./git-workflow.md#the-changelog-is-a-release-time-activity--never-at-push-time)).

## Xcode version

Build with the latest **final** Xcode — never a beta/RC, and never an older release once a newer
final ships. Both trigger **ITMS-90111** (Unsupported SDK or Xcode version) on upload.

## Release flow

1. Write the release notes in English under `## Unreleased` in `CHANGELOG.md` (grouped `### New` /
   `### Fixes`), then the French translation under `## Unreleased` in `CHANGELOG.fr.md`. Rename
   the `## Unreleased` heading in **both** files to `## <version> (<YYYY.MM.DD>)` (e.g.
   `## 1.0 (2026.08.01)`) — matching the version you are about to upload. There is no CI
   date-stamp; versioning is manual.
2. **Push `main`** — the Deploy workflow regenerates the served changelog asset
   (`server/system/changelog-content.ts`) from `CHANGELOG.fr.md` via `bun run generate:assets`.
   This step is **required for the in-app changelog**: the notes only reach the app once a `main`
   deploy has rebuilt the asset. The app shows the version as the row title and the date on the
   right; a plain `## Unreleased` would display literally as "Unreleased", so make sure it was
   versioned in step 1.
3. Archive, export and upload to App Store Connect, bumping `CURRENT_PROJECT_VERSION` in
   `project.pbxproj` for every new upload.

## Beta-macOS build machines

If the dev Mac runs a **beta macOS**, archives get a prerelease `BuildMachineOSBuild` stamp that
App Store validation also rejects with ITMS-90111. After archiving, patch it to the latest
**public** macOS build number *before* `-exportArchive` (export re-signs, so the patch survives):

```bash
# after `xcodebuild ... archive`, before `-exportArchive`:
plutil -replace BuildMachineOSBuild -string '<latest public macOS build>' \
  build/Shuhari.xcarchive/Products/Applications/Shuhari.app/Info.plist
```

Look up the current public macOS build at https://developer.apple.com/news/releases. Verify
`DTXcodeBuild`/`DTSDKBuild` are untouched, then export. The clean alternative is to archive on a
non-beta macOS (e.g. a CI macOS runner with the final Xcode) — no patch needed.
