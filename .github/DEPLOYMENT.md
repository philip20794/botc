# Automatic production deployment

The `.github/workflows/android-latest.yml` workflow deploys both distribution
channels on every push to `main` and can also be started from **Actions → Deploy
Android APK and Firebase Hosting → Run workflow**.

The workflow waits for static analysis, Flutter/widget tests, Firestore rule
emulator checks and Android integration tests before publishing either output.

- **Android APK:** Builds a release-signed APK and uploads `b-o-t-c.apk` to
  [android-latest](https://github.com/philip20794/botc/releases/tag/android-latest).
- **Web/PWA:** Builds `flutter build web --release` to `build/web` and runs
  `firebase deploy --only hosting --project b-o-t-c --non-interactive` to
  [b-o-t-c.web.app](https://b-o-t-c.web.app/).

These two publication jobs run independently, so an APK signing failure does
not block a working web release, or vice versa. Later pushes on `main` cancel
older, still-running production workflows.

## One-time GitHub Actions credentials

The Android release uses the repository's existing signing secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

For Firebase Hosting, add the following GitHub Actions repository secret, if
it does not already exist:

**Secret name:** `FIREBASE_SERVICE_ACCOUNT_B_O_T_C`

**Secret value:** The entire JSON key for a Google Cloud service account in
Firebase project `b-o-t-c` that is authorized to deploy Firebase Hosting
(e.g. with Firebase Hosting Admin permission). Store the JSON **only in GitHub
Actions Secrets**, never in Git, a local config file committed to the repo,
or a Flutter asset.

Open **GitHub repository → Settings → Secrets and variables → Actions → New
repository secret** to configure it. The workflow reports a clear error when
the secret is absent; it does not silently skip deploying the web app.

When both sets of secrets are configured, pushing to `main` requires no
manual `flutter build` or `firebase deploy` command.

## Verification before merge

`.github/workflows/flutter-pr-checks.yml` also builds a production Web
release on pull requests. This confirms web compilation without deploying
feature branches to the public site.
