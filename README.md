# A7-TAGAM customer app

Flutter customer app for ordering food in Ashgabat. Customers browse the menu, choose an address, pay cash on delivery, and follow their order. The app supports Turkmen and Russian.

## Install

- [Google Play](https://play.google.com/store/apps/details?id=com.gurbanov.alowalow)
- [App Store](https://apps.apple.com/us/app/a7-tagam/id6803538512)
- [GitHub Release v2.0.1](https://github.com/Dadebay/Food_delivery_alow_alow/releases/tag/v2.0.1) — Android build 21 and release notes.
- [Download the signed Android APK](https://github.com/Dadebay/Food_delivery_alow_alow/releases/download/v2.0.1/A7-TAGAM-v2.0.1-build21-android.apk) · [SHA-256 checksum](https://github.com/Dadebay/Food_delivery_alow_alow/releases/download/v2.0.1/A7-TAGAM-v2.0.1-build21-android.apk.sha256)

The published store version is 2.0.0. The GitHub APK is version 2.0.1+21 and has not been submitted to either store. Its compatibility with updates from a Play-installed copy has not been verified against Google's app-signing certificate, and a real-device install test was not performed. Prefer the store listing if the app is already installed from a store.

## Run and test

Use Flutter 3.47.8 (Dart 3.13.7) or a compatible newer stable version.

```bash
flutter pub get
flutter run
```

The normal build connects to the production API at `https://a7-tagam.com.tm/api/v1/`. For local, isolated demonstrations, enable the bundled mock repositories:

```bash
flutter run --dart-define=USE_MOCK_DATA=true
```

The mock SMS code is `000000`. Mock mode does not place a real order. The live app requires a working backend and SMS service.

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

GitHub Actions runs these checks and unsigned Android/iOS build checks on pull requests and `main`.

## Configuration

| Dart define | Purpose |
| --- | --- |
| `API_BASE_URL` | Main API endpoint. Defaults to the production HTTPS hostname. |
| `API_FALLBACK_URL` | Optional alternate HTTPS hostname with a valid TLS certificate. Empty by default. |
| `USE_MOCK_DATA` | `true` uses bundled mock data. Defaults to `false`. |
| `SHOW_PROMO_CODE` | Shows the promo field when the backend supports it. Defaults to `false`. |

The production API, map tiles, and routing service need to be checked before each store rollout. Do not add a raw-IP fallback with a certificate mismatch: login and order data require normal TLS validation.

## Main flows

- Menu, search, favorites, cart, gift points, and checkout
- Address selection on a map, with district and building details
- Cash on delivery
- Order history and courier tracking
- Phone/SMS authentication, language selection, and support

Checkout obtains prices from the backend. A local estimate is marked as approximate if a quote cannot be retrieved; the backend recalculates the final amount when creating an order. Order retries reuse an idempotency key for the same basket to avoid duplicate orders after a timeout.

The checkout UI is divided into `lib/modules/checkout/checkout_screen.dart`, section widgets, pricing widgets, dialogs, and a pure pricing calculator. Repository models live under `lib/core/models/`; network calls live under `lib/core/data/` and `lib/core/network/`.

## Release

The Android application ID and iOS bundle ID are both `com.gurbanov.alowalow`. The current source version is set in `pubspec.yaml`. Increase the version name/build code for a new store submission.

```bash
flutter build appbundle --release
flutter build ipa --release
```

Android release builds require `android/key.properties` and its upload keystore, kept outside Git. They fail when the signing files are absent. Do not upload a debug-signed artifact. iOS distribution requires the team's signing setup in Xcode. Check the package ID, signature, backend compatibility, upgrade path, and core order flow on real devices before publishing. Save signed artifacts and symbols securely, then create a tagged GitHub Release with the released commit and test evidence. Use staged rollout and monitor order failures; roll back through the store if necessary.

**Known release blocker:** the backend has no account-deletion endpoint. The app offers sign-out only; it must not claim that signing out deletes the account. Implement and verify account deletion with the backend before claiming this flow or submitting a release that requires it.

## Assets and permissions

The map asks for location only when a customer chooses to use their current position. Dish and banner photos can be placed under `assets/images/dishes/` and `assets/images/banners/`; missing images use the app's fallback visuals. Review all SDK permissions and store privacy disclosures against each release build.
