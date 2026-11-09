# LiNGUiD for iOS

LiNGUiD helps people learn languages through real short-form video. Watch at your level, tap captions for help, and save words to practice later.

[Product site](https://learnwithlinguid.com/) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md)

## Run locally

1. Clone this repository and open `LiNGUiD.xcodeproj` in Xcode with the iOS SDK installed. The main app targets iOS 17.6 or later.
2. Select the shared **LiNGUiD** scheme and let Xcode resolve its Swift Package Manager dependencies.
3. For backend development, create a separate Firebase project, register an iOS app with your development bundle ID, and use that project's `GoogleService-Info.plist` at `Resources/GoogleService-Info.plist`. Keep your config changes local. Some features also require matching Firebase rules, test data, and sign-in providers; never point test builds at production user data.
4. Choose an iOS simulator and press **Run**. For a physical device, configure your own signing team and supported entitlements. The repository contains the client, so server-dependent features may be unavailable in a fresh development project.

The legacy Cloud Translation integration on `main` has no working key configured. Do not embed a replacement paid API key in the app. Route production translation through an authenticated backend that keeps the credential server-side.

## Project layout

| Path | Purpose |
| --- | --- |
| `App/`, `Coordinators/` | App entry point and navigation |
| `Views/`, `View Models/` | SwiftUI screens and UI state |
| `Models/`, `Services/`, `Utilities/` | Data models, integrations, and shared logic |
| `Resources/` | App assets and configuration |
| `StoreKit.storekit` | Local subscription configuration |

This is the iOS client, separate from the [LiNGUiD website](https://learnwithlinguid.com/). No open-source license has been selected for this repository.
