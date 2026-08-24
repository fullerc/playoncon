# Play On Con changelog

Newest first. Every store upload gets an entry: `## <version> (build <n>) — <date>`.
The build number is the `+N` in `pubspec.yaml` — one integer shared by TestFlight
and Google Play, and it only ever goes up. The ship skill reads the newest entry
here to find the previous release.

## 2026.7.12 (build 27) — 2026-07-12

- Last release under the old date-based scheme (marketing version = ship date).
  From here on the version is semantic, matching LockItUp: patch for fixes,
  minor for features, major for redesigns — components move by what shipped,
  not the calendar, and never backward.
