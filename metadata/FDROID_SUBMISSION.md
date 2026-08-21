# F-Droid submission guide

This repo ships draft metadata for both apps under `metadata/`. Listing on
f-droid.org requires a merge request against
[fdroiddata](https://gitlab.com/fdroid/fdroiddata).

## Before opening the GitLab MR

1. Merge the screenshots / metadata PR to `main` (icons already on main).
2. Create an annotated release tag matching the metadata `commit:` field:
   ```bash
   git checkout main && git pull
   git tag -a v0.3.3 -m "Kinetic 0.3.3 for F-Droid"
   git push origin v0.3.3
   ```
3. Confirm Flutter **3.44.1** builds both APKs locally:
   ```bash
   ./tool/fdroid_build.sh parent
   ./tool/fdroid_build.sh kids
   ```
4. Phone screenshots live under
   `metadata/*/en-US/images/phoneScreenshots/` (`01.png`, `02.png`, …).
5. Copy into an fdroiddata fork:
   - `metadata/net.moonbaseone.kinetic.parent.yml`
   - `metadata/net.moonbaseone.kinetic.kids.yml`
   - `metadata/net.moonbaseone.kinetic.parent/en-US/` (screenshots + icon)
   - `metadata/net.moonbaseone.kinetic.kids/en-US/` (screenshots + icon)
6. Open one GitLab MR (or two) against `fdroid/fdroiddata` `master`.

## Reproducible builds

- Flutter is pinned (`3.44.1` in CI, `.flutter-version`, `.fvmrc`, and
  `srclibs: flutter@3.44.1`).
- Workspace Melos bootstrap is part of `prebuild`.
- F-Droid rebuilds and **re-signs** APKs with the F-Droid key; GitHub Release
  signing is independent.
- Local DB encryption uses SQLite3MultipleCiphers via pub workspace hooks
  (`hooks.user_defines.sqlite3.source: sqlite3mc`).

## Privacy

`PrivacyPolicy:` points at
https://raw.githubusercontent.com/ingmarstruijs/Kinetic/main/PRIVACY.md
