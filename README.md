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
- Remembers the email of the last sign-in (the password goes to Android's
  password manager via autofill)
- Hook for Google OAuth (`signInWithGoogle()` in `auth_service.dart`)
- **AI Providers list** (after login): switch catalogue entries on and off,
  store your own API key on the device, provider logos, links to the provider
  login and API-key pages. The catalogue itself is maintained by a PocketBase
  superuser, on the web page

## Stack

| Package | Purpose |
| --- | --- |
| `dio` | HTTP client for the REST API |
| `flutter_riverpod` | state management |
| `go_router` | navigation + auth-status routing |
| `flutter_secure_storage` | secure token storage and AI provider API keys |
| `equatable` | model comparison |
| `url_launcher` | opening provider login / API-key pages |
| `flutter_svg` | provider logos from `assets/logos` |

## Structure

```
lib/
├── core/
│   ├── config.dart          # baseUrl and collection name
│   └── constants.dart       # storage keys
├── models/
│   ├── action_result.dart   # outcome of the last register/login attempt
│   ├── ai_config.dart       # catalogue document + canEdit flag
│   ├── ai_provider.dart     # one provider entry + its status
│   └── user.dart            # user model + displayName
├── providers/
│   ├── action_result_provider.dart
│   ├── ai_providers_provider.dart # catalogue view, enable flags, keys
│   └── auth_provider.dart   # AuthNotifier + Riverpod providers
├── services/
│   ├── ai_config_sync_service.dart # GET/PUT /api/ai-config
│   ├── api_client.dart      # Dio + auth header
│   ├── auth_service.dart    # register / login / logout / availability
│   └── secure_storage_service.dart
├── screens/
│   ├── ai_providers_list_screen.dart
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── action_result_screen.dart
│   └── home_screen.dart
├── utils/
│   └── validators.dart      # form field validation
└── main.dart                # MaterialApp.router + redirects

assets/
└── logos/                   # provider logos (SVG)
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
| List/Search | `@request.query.k = 'pb_av_1' && @request.query.q != '' && (email = @request.query.q \|\| name = @request.query.q)` |
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

The secret value of the `k` parameter (`AppConfig.availabilitySecret`, name in
`AppConfig.availabilityParam`) guards against bulk enumeration. It can be
extracted from the APK, so it protects against casual scanning rather
than a determined attacker. The `@request.query.q != ''` guard is mandatory:
without it a request with no `q` matches records whose `name` or `email` is
empty. The `email` field is additionally hidden by the
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

## AI Providers list

Reachable from the home screen (`AI-провайдеры` → `/ai-providers`). One card
per provider, sorted by `fallbackPriority`, each with:

- an enable / disable switch
- `URL`, `Model`, `API Key` (masked) and `Fallback priority`
- links to the provider login page and the API-key page (`url_launcher`)
- `Edit` / `Delete` (delete asks for confirmation)
- a logo: `logoUrl` → `logoAsset` (`assets/logos/<name>.svg`) → generic icon

New providers are added with `Add new provider`. On the first visit the list is
seeded with popular providers (OpenAI, Anthropic, Google Gemini, Groq,
OpenRouter, Ollama, LM Studio, Mistral, Together, Fireworks).

### Storage: config on the server, secrets on the device

| What | Where |
|---|---|
| name, enabled, url, model, fallbackPriority, links, logo | PocketBase collection `ai_providers` |
| API key | `flutter_secure_storage`, key `ai_provider_<userId>_<providerId>` |

The API key never leaves the device: the sync service strips `api_key` from
every request, the server drops it as well, and the key itself lives in secure
storage — so it is not in the database, in backups or in server logs.

### API Rules for the `ai_providers` collection

| Rule | Value |
|---|---|
| List/Search | `@request.auth.id != '' && user = @request.auth.id` |
| View | `@request.auth.id != '' && user = @request.auth.id` |
| Create | `@request.auth.id != ''` |
| Update | `@request.auth.id != '' && user = @request.auth.id` |
| Delete | `@request.auth.id != '' && user = @request.auth.id` |

Fields: `user` (relation → `users`, required), `name` (text, required),
`enabled` (bool), `url` (url, required), `model` (text, required),
`fallbackPriority` (number, min 0), `loginUrl`, `getApiKeyUrl`, `logoUrl` (url),
`logoAsset` (text), `isPredefined` (bool).

> No `api_key` field is needed on the server — the key lives on the device only.

### Who may change what

Provider definitions live in one shared catalogue on the server
(`pb_data/ai-config/catalogue.json`). Every entry has an origin:

| Origin | Added by | Seen by |
|---|---|---|
| `admin` | a PocketBase superuser | everybody |
| `user` | a regular user | its author and the superuser, until an administrator publishes it |

A regular user **can** add a provider of their own. It is reported to the
administrator together with the author's name and all of its data except
secrets, and it stays invisible to other users until an administrator switches
it to `admin` — that is what the “Видят” field on the web page is for.

A regular user may edit and delete their **own** entries. An administrator's
entry allows exactly one thing: entering your own API key, which stays on the
device.

The same list is in a browser at `https://app.devhorizon.online/ai-providers/`
(PocketBase serves that page itself, so it is the same origin). There an
administrator ticks “Вход администратора (superuser)” to manage the catalogue;
a regular account only gets the switches.

Tapping the **API Key** line opens the key dialog, which has a
**«Вставить из буфера»** button — it becomes active only once the field is
focused.

On every sync only the entries a user switched **off** are reconciled:

| Situation | What happens |
|---|---|
| still in the catalogue | kept, and the fresh URL / model is taken from it |
| `status: dead` | dropped — the mark that the provider stopped working |
| no longer in the catalogue | dropped |

Entries switched **on** are never touched: their URL, model and key stay as the
user left them, even when the catalogue marks them dead.

API keys never reach the server: they stay in `flutter_secure_storage` on the
device, and the server drops an `api_key` field even if one is sent by hand.

The **email** of the last successful sign-in is remembered and prefilled; the
password is not stored by the app — Android's password manager fills it in
through the autofill hints.

### Provider test and the shared statistics

Every provider card has **Проверить и список моделей**. It calls the provider's
own `/models` endpoint with your key — which doubles as the API key check — and
shows the models that came back. Saving a new key runs the test right away.

The button is disabled, and the server refuses the report as well, for a
provider the administrator marked as `dead`.

The outcome is published immediately to `/api/ai-stats`, so next to every model
you see how many users succeeded, how many ran into an error in brackets, and
when the last report arrived:

```text
gpt-4o-mini   5 (2) · 12.10 21:15
```

A test counts as a success only when the key is accepted **and** the provider
offers the configured model; that way the counters show which models people
cannot actually use. The web page refreshes the numbers every few seconds, and
the app shows them next to the model too.

Once real AI calls are wired into the app, the same endpoint is where their
provider + model outcomes belong.

## Build

```bash
flutter pub get
flutter build apk --debug     # test APK
flutter build apk --release   # release APK (requires a keystore)
```

The APK ends up in `build/app/outputs/flutter-apk/`.

> **Release builds need the INTERNET permission.** Flutter keeps
> `android.permission.INTERNET` only in `android/app/src/debug/AndroidManifest.xml`
> (for hot reload), so a release APK has no network at all until it is declared
> in `android/app/src/main/AndroidManifest.xml`. Without it every request fails
> with `SocketException: Failed host lookup ... errno = 7`, which looks like a
> DNS problem but is not one.

### Windows: pub cache on a different drive

If the project and the pub cache live on different Windows drives (project on
`E:`, cache on `C:`, for example), the Kotlin incremental compiler fails with
`this and base files have different roots`. This is already handled in
`android/gradle.properties`:

```properties
kotlin.incremental=false
kotlin.incremental.useClasspathSnapshot=false
```

## Deployment (self-hosted PocketBase)

`deploy/` holds everything needed to keep the backend up:

| File | Purpose |
|---|---|
| `install-pocketbase-service.sh` | installs PocketBase as a systemd service (`Restart=always`, autostart on boot) |
| `pocketbase.service` | reference copy of the unit file |
| `create-ai-providers-migration.js` | PocketBase migration that creates the `ai_providers` collection |
| `tighten-users-list-rule.js` | PocketBase migration closing the empty-`q` leak in the `users` List rule |
| `catalogue.json` | the initial provider catalogue (10 entries, all `active`) |
| `pb_hooks/` | the `/api/ai-config` and `/api/ai-stats` routes plus their logic modules |
| `pb_public/ai-providers/` | the web page served at `/ai-providers/` |
| `README.md` | step-by-step instructions |

```bash
sudo ./deploy/install-pocketbase-service.sh
cp deploy/create-ai-providers-migration.js \
   ~/pocketbase/pb_migrations/1791463000_create_ai_providers.js
cp deploy/tighten-users-list-rule.js \
   ~/pocketbase/pb_migrations/1791463100_tighten_users_list_rule.js
cp -r deploy/pb_hooks/*  ~/pocketbase/pb_hooks/
cp -r deploy/pb_public/* ~/pocketbase/pb_public/
cp deploy/catalogue.json ~/pocketbase/pb_data/ai-config/catalogue.json
sudo systemctl restart pocketbase
```

Without the service PocketBase only lives as long as the SSH session that
started it — that is what used to turn the API into a 502.

## Tests

```bash
flutter test
```

The suite covers the models, the result screen, the full register / login /
logout flow and the AI providers flow (add, edit, toggle, delete, and the
"the API key never reaches the server" guarantee).

The availability check against the real server is opt-in:

```bash
flutter test test\availability_integration_test.dart --dart-define=PB_LIVE=true
```

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
