---
name: ship
description: "Ship the current working-directory changes to BOTH TestFlight (iOS) and Google Play internal testers (Android). Bumps the semantic X.Y.Z+N version in pubspec.yaml, runs the iOS and Android builds sequentially, uploads to both stores in parallel, commits the changed files + pubspec bump + CHANGELOG.md entry, pushes to remote, and writes release notes. Invoke when the user says something like 'ship this', 'ship it', 'commit and push this, add a new version number and push to testers', 'ship this to Play', 'ship to TestFlight', or any close variant."
---

# Ship to TestFlight + Play internal testers (PlayOnCon)

Fuller's one-shot flow for getting a change from working tree → both TestFlight and Play Console internal track in a single pass. Runs the whole pipeline without asking; the standing store-upload authorization applies to the push step.

Store credentials come from the `store-upload-credentials` memory — don't re-ask for the ASC Key ID / Issuer ID / package name / JSON path.

## Preconditions to check silently

- `git status --short` shows only intentional changes (no stray files you don't recognize — if you see any, stop and ask).
- `scripts/.env.local` exists (both build scripts source it).
- `~/.playconsole/playoncon-publisher.json` exists.
- `~/.appstoreconnect/private_keys/AuthKey_<key-id>.p8` exists.

If any debug `flutter run` task is still running in the background, `TaskStop` it before building — Gradle and `flutter run` both share `.dart_tool` and will collide.

## Step 1 — Set the version

The version string in `pubspec.yaml` is `X.Y.Z+N` — one **semantic marketing version** (two or three numeric components, no suffixes) plus one build number, shared by both stores from this single line (iOS reads `FLUTTER_BUILD_NAME`/`FLUTTER_BUILD_NUMBER`, Android reads `flutter.versionName`/`flutter.versionCode`). Same scheme as LockItUp: the components move by **what shipped**, never by the calendar.

Find the previous release in the newest `CHANGELOG.md` entry (it records the build number) and cross-check `pubspec.yaml` — in this flow pubspec is committed only after both uploads succeed, so it records what last shipped. If the two disagree, trust the higher build number and flag the mismatch.

Read `pubspec.yaml`, then:

- **Marketing version**: bump by change type since the last ship — fixes only → patch (`2026.7.12` → `2026.7.13`), user-visible features → minor (`2026.7.12` → `2026.8.0`), a redesign or compatibility break → major (`2026.7.12` → `2027.0.0`). If the user names a version, use it. Say which bump you chose and why.
- **Build number `+N`**: previous + 1. Monotonic across the whole app — TestFlight and Play both require it to strictly increase, regardless of whether the marketing version changed. Never reset it.

Both parts only ever move forward — Apple rejects a marketing version below one that already shipped. The `2026.x` range is historical: through `2026.7.12+27` the app used a date-based scheme (marketing = ship date), and the semantic scheme continues numerically from there. Version numbers that look like dates are a leftover of that history, not a rule. Never renumber downward (e.g. to `1.0.0`).

## Step 2 — Build both artifacts (sequentially)

Both builds share `.dart_tool`, so run them one at a time. iOS first — signing issues surface faster than Gradle failures.

```bash
./scripts/build-testflight.sh    # ~1–2 min, produces build/ios/ipa/*.ipa
./scripts/build-play.sh          # ~1–2 min, produces build/app/outputs/bundle/release/app-release.aab
```

Run each as a background task with a 10-minute timeout. Success lines:

- iOS: `✓ Built IPA to build/ios/ipa (~30MB)`
- Android: `✓ Built build/app/outputs/bundle/release/app-release.aab (~55MB)`

The Kotlin Gradle Plugin (KGP) warning on Android is benign — ignore it.

## Step 3 — Upload to both stores (in parallel)

Different APIs, no shared state — dispatch both uploads in the same message as parallel background tasks.

### iOS → TestFlight

```bash
xcrun altool --upload-app \
  --type ios \
  -f build/ios/ipa/*.ipa \
  --apiKey <from store-upload-credentials memory> \
  --apiIssuer <from store-upload-credentials memory>
```

Long-running (~2 min normal, up to 25 min if Apple's API is flaky — altool retries on transient 500s, don't kill it). Give this background task a **20-minute timeout**. Success line:

```
UPLOAD SUCCEEDED with no errors
```

Build appears in TestFlight after Apple processes it (typically 10–30 min after upload completes).

### Android → Play internal

```bash
fastlane supply \
  --aab build/app/outputs/bundle/release/app-release.aab \
  --package_name com.fuller.playoncon \
  --json_key ~/.playconsole/playoncon-publisher.json \
  --track internal \
  --skip_upload_metadata true \
  --skip_upload_changelogs true \
  --skip_upload_images true \
  --skip_upload_screenshots true
```

Typical end-to-end ~30 s. Success line:

```
Successfully finished the upload to Google Play
```

## Step 4 — Commit and push

Only after **both** uploads have succeeded — never commit a version bump that only shipped to one store, because the next ship attempt will re-bump and skip the failed store.

First prepend the release entry to `CHANGELOG.md` (newest first) — this is the durable record the next ship's Step 1 reads:

```markdown
## <version> (build <n>) — <yyyy-mm-dd>

- <the short-form bullets from Step 5 — write them now>
```

Stage by **explicit path** — never `git add .` / `-A`. Include:

- Every file listed by `git status --short` that was part of what shipped (source + test edits).
- `pubspec.yaml`.
- `CHANGELOG.md`.

Exclude machine-specific noise: `ios/Runner.xcodeproj/project.pbxproj` (unless the user says otherwise), `android/local.properties`, `Pods/`, `.dart_tool/`.

Commit message: one line summarizing what shipped, ending with `; bump to <version>`. Follow the repo's existing style (see `git log --oneline -5`):

```
<short summary of the change>; bump to 2026.7.13+28
```

If there's a compelling "why," add a body paragraph — but keep it tight. Then:

```bash
git push
```

Standing authorization applies — no need to ask before pushing. Push only the current branch, never force-push.

## Step 5 — Write release notes

At the end of the run, emit release notes in two forms so Fuller can paste either into Play Console / App Store Connect (both have per-build "What to test" fields) or share with the team:

**Short (store consoles):** bullet list, under 500 chars, user-facing language ("Rocky Horror now starts at 11:30 PM", not "parser fix"). Focus on what the tester will *see or feel*, not the implementation. This is the same text committed to `CHANGELOG.md` in Step 4 — reuse it, don't rewrite it.

**Longer (team/internal):** 3–6 bullets with the technical framing — what changed, why, and any behavior detail that matters when triaging feedback.

Derive both from the commit body plus the file diff — don't invent features. If the change is purely mechanical (build number only), say so and skip the short form.

## Failure modes to recognize fast

- **Edit rejected because pubspec.yaml wasn't read this turn** → Read it, then Edit. Common when resuming from a summary.
- **Debug run still holds the build cache** → TaskStop the flutter run task before invoking either build script.
- **fastlane "APK specifies a version code that has already been used"** → the +N didn't get baked in; re-verify pubspec and rerun the build.
- **fastlane "Package not found"** → someone changed the package name; the current value is `com.fuller.playoncon`.
- **altool "Invalid Pre-Release Train. The train version 'X.Y.Z' is closed"** (error 90186) → Apple has closed that marketing-version train (typically because that version was released on the App Store). Bump the patch component (`2026.7.13` → `2026.7.14`), rebuild both platforms so they stay on one version, and note the extra bump in the commit message.
- **altool 401 / "App not found"** → wrong ASC Key ID + Issuer ID pair, or the `.p8` file is missing. The credentials memory has the correct values.
- **One store succeeded, the other failed** → do NOT commit yet. Fix the failure, re-upload only the failed store using the already-built artifact (no rebuild needed unless the artifact is stale), then commit once both are up.
- **iOS export-compliance halts the build** → `ITSAppUsesNonExemptEncryption=false` should already be set in `ios/Runner/Info.plist`; if it's missing, add it before rebuilding.
