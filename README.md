> **English** · [Русский](README.ru.md) · [Deutsch](README.de.md)

# Login Template (Flutter + PocketBase)

Android app template with authentication: **registration**, **login**, **logout**
and a `You are logged in as ...` screen after a successful sign-in.

## Features

- Registration: `email + username + password + confirm password`
- Password requirements with a live checklist (minimum 8 characters, passwords must match)
- Result screen after every registration and login: a success confirmation or an error description, with "Go to sign in" for registration
- Live availability check for email and username (busy / free while typing)
- Login with `email + password`
- Auto-login on app start (session restore)
- Token stored in `flutter_secure_storage`
- Home screen: `You are logged in as <username / email / id>`
- Logout with confirmation
- Splash screen while the session is being restored
- Hook for Google OAuth (`signInWithGoogle()` in `auth_service.dart`)

## Stack

| Package | Purpose |
| --- | --- |
| `dio` | HTTP client for the REST API |
| `flutter_riverpod` | state management |
| `go_router` | navigation + auth-status routing |
| `flutter_secure_storage` | secure token storage |
| `equatable` | model comparison |

## Structure

```
lib/
├── core/
│   ├── config.dart          # baseUrl and collection name
│   └── constants.dart       # storage keys
├── models/
│   ├── action_result.dart   # outcome of the last register/login attempt
│   └── user.dart            # user model + displayName
├── providers/
│   ├── action_result_provider.dart
│   └── auth_provider.dart   # AuthNotifier + Riverpod providers
├── services/
│   ├── api_client.dart      # Dio + auth header
│   ├── auth_service.dart    # register / login / logout / availability
│   └── secure_storage_service.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── action_result_screen.dart
│   └── home_screen.dart
├── utils/
│   └── validators.dart      # form field validation
└── main.dart                # MaterialApp.router + redirects
```

## Backend

The backend is a self-hosted [PocketBase](https://pocketbase.io) instance on a
server, reachable through a Cloudflare Tunnel.

- API base URL: `https://app.devhorizon.online`
- Collection: `users` (built-in `auth` type)
- Endpoints: `POST /api/collections/users/records` (registration),
  `POST /api/collections/users/auth-with-password` (login)

Changing the base URL is a one-file change:

```dart
// lib/core/config.dart
static const String baseUrl = 'https://your-domain.example';
```

### Name field

PocketBase's built-in `users` collection has **no `username` field** — the
system field `name` is used instead. The app sends and reads exactly that:

```dart
'name': username.trim()          // on registration
json['name'] ?? json['username'] // when reading
```

### API Rules for the `users` collection

| Rule | Value |
|---|---|
| List/Search | `@request.query.k = 'pb_av_1' && (email = @request.query.q \|\| name = @request.query.q)` |
| View | `- Superusers only` |
| Create | *(empty)* — registration is open |
| Update | `@request.auth.id = id` |
| Delete | `- Superusers only` |

The List/Search rule exists solely for the availability check. The request

```text
GET /api/collections/users/records?k=pb_av_1&q=someone@example.com
```

returns at most one match and nothing in every other case (no `k`, no `q`,
any other `filter`). Meaning of `totalItems`:

- `1` — the value is taken
- `0` — the value is free

The secret `k` (`AppConfig.availabilityKey`) guards against bulk enumeration.
It can be extracted from the APK, so it protects against casual scanning rather
than a determined attacker. The `email` field is additionally hidden by the
response (`emailVisibility = false`) — only the fact of existence leaks.

> ⚠️ The `name` field is **not unique** (PocketBase cannot add a unique index
> to an arbitrary text field). The check reports "Taken", but the server would
> technically accept a duplicate. Uniqueness of `email` is guaranteed by an index.

## Result screens

Every register / login attempt ends on a result screen (`/register-result`,
`/login-result`) that shows either a confirmation of success or the error
description:

| Case | Headline | Buttons |
|---|---|---|
| Registration OK | Регистрация прошла успешно | Перейти к входу · Создать ещё один аккаунт |
| Registration failed | Регистрация не выполнена | Попробовать снова · Перейти к входу |
| Login OK | Вход выполнен | Перейти в профиль |
| Login failed | Вход не выполнен | Попробовать снова · Создать аккаунт |

The outcome travels through `actionResultProvider`, so a redirect firing
while the request is in flight cannot lose it. Failures are *pushed* onto the
stack, so pressing Back returns to the still-filled form.

## Build

```bash
flutter pub get
flutter build apk --debug     # test APK
flutter build apk --release   # release APK (requires a keystore)
```

The APK ends up in `build/app/outputs/flutter-apk/`.

## Extension point for social login

In `lib/services/auth_service.dart`:

```dart
Future<void> signInWithGoogle() async {
  // TODO: enable Google OAuth in PocketBase (Settings > Auth providers)
}
```

Enabling the provider in PocketBase and filling in this method is all it takes
to add Google sign-in without reworking the screens.

## License

MIT
