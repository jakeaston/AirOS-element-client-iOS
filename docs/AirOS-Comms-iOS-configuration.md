# AirOS Comms on Element X iOS

This fork can replace the stock Matrix sign-in flow with the **AirOS session bridge**: the app loads your AirOS web sign-in page, then calls `GET /{organisation}/communications/matrix/session` with the same session cookies as the web client, and restores a Matrix Rust SDK session from the returned `accessToken`, `matrixUserId`, and `homeserverUrl`.

## Enabling the bridge

Set the following keys in the **ElementX** target `Info.plist` (via Xcode or `ElementX/SupportingFiles/target.yml` under `targets: ElementX: info: properties:`). All string values must be non-empty when the feature is on.

| Key | Type | Purpose |
|-----|------|---------|
| `airOSCommsEnabled` | Boolean | `true` to enable the bridge and lock homeserver selection. |
| `airOSCommsAPIBaseURL` | String | HTTPS base URL of the AirOS Node API (e.g. `https://app.example.com`), no trailing slash required. |
| `airOSCommsWebSignInURL` | String | Full URL of the AirOS sign-in page to load in the embedded `WKWebView`. |
| `airOSCommsOrganisationSlug` | String | Tenant slug used in the session path (`/{organisation}/communications/matrix/session`). |
| `airOSCommsMatrixServerName` | String | Server part of MXIDs (e.g. `comms.example.com`); must match Synapse `server_name` / delegation. |

When `airOSCommsEnabled` is `true` but any required value is missing, the app logs an error and continues with the **default Element X** authentication flow.

## Runtime behaviour

1. On first launch (no keychain session), the app shows the **AirOS bridge** screen: embedded web sign-in and a **Continue** button.
2. **Continue** copies cookies from `WKWebsiteDataStore.default()` into `HTTPCookieStorage.shared`, then requests the matrix session JSON.
3. On success, the app builds a Rust `Client`, calls `restoreSession`, and persists credentials like a normal login (`UserSessionStore`).
4. `AppSettingsHook` registers **`AirOSAppSettingsHook`**, which sets `allowOtherAccountProviders` to `false` and `accountProviders` to your `airOSCommsMatrixServerName`.

## Backend contract

See your AirOS guide: the session endpoint must return `success`, `configured`, `matrixUserId`, `accessToken`, `homeserverUrl`, and ideally **`deviceId`** (Synapse admin login already has it). If `deviceId` is omitted, the client calls **`GET /_matrix/client/v3/account/whoami`** once to obtain it.

## Security

- Never log `accessToken` or session JSON bodies.
- Anyone with a valid AirOS session for a user can obtain that user’s Matrix token via this endpoint—the same trust model as the web communications UI.
