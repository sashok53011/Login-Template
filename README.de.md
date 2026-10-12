> [English](README.md) · [Русский](README.ru.md) · **Deutsch**

# Login Template (Flutter + PocketBase)

Android-App-Vorlage mit Authentifizierung: **Registrierung**, **Anmeldung**,
**Abmelden** und ein Bildschirm `Sie sind angemeldet als ...` nach erfolgreicher
Anmeldung.

## Funktionen

- Registrierung: `E-Mail + Benutzername + Passwort + Passwort bestätigen`
- Passwortanforderungen mit Live-Checkliste (mindestens 8 Zeichen, Passwörter müssen übereinstimmen)
- Ergebnisbildschirm nach jeder Registrierung und Anmeldung: Erfolgsmeldung oder Fehlerbeschreibung, bei der Registrierung mit Schaltfläche „Zur Anmeldung"
- Live-Verfügbarkeitsprüfung für E-Mail und Benutzername (belegt / frei während der Eingabe)
- Anmeldung mit `E-Mail + Passwort`
- Automatische Anmeldung beim App-Start (Sitzung wird wiederhergestellt)
- Token wird in `flutter_secure_storage` gespeichert
- Startbildschirm: `Sie sind angemeldet als <Benutzername / E-Mail / id>`
- Abmelden mit Bestätigung
- Splash-Bildschirm, während die Sitzung wiederhergestellt wird
- Ansatz für Google OAuth (`signInWithGoogle()` in `auth_service.dart`)
- **AI Providers list** (nach der Anmeldung): Ein-/Ausschalten, bearbeitbare
  URL / Model / API-Key / Fallback-Priorität, Anbieter-Logos, Links zu
  Login- und API-Key-Seite, Add / Edit / Delete

## Stack

| Paket | Zweck |
| --- | --- |
| `dio` | HTTP-Client für die REST-API |
| `flutter_riverpod` | Zustandsverwaltung |
| `go_router` | Navigation + Routing nach Anmeldestatus |
| `flutter_secure_storage` | Sichere Speicherung von Token und API-Keys |
| `equatable` | Vergleich von Modellen |
| `url_launcher` | Öffnen von Login- / API-Key-Seiten |
| `flutter_svg` | Anbieter-Logos aus `assets/logos` |

## Struktur

```
lib/
├── core/
│   ├── config.dart          # baseUrl und Collection-Name
│   └── constants.dart       # Speicherschlüssel
├── models/
│   ├── action_result.dart   # Ergebnis der letzten Registrierungs-/Anmeldeversuche
│   ├── ai_provider.dart     # Konfiguration eines AI-Anbieters
│   └── user.dart            # Benutzermodell + displayName
├── providers/
│   ├── action_result_provider.dart
│   ├── ai_providers_provider.dart # Anbieter + Liste der beliebten Anbieter
│   └── auth_provider.dart   # AuthNotifier + Riverpod-Provider
├── services/
│   ├── ai_providers_service.dart  # CRUD für die Collection ai_providers
│   ├── api_client.dart      # Dio + Auth-Header
│   ├── auth_service.dart    # register / login / logout / Verfügbarkeit
│   └── secure_storage_service.dart
├── screens/
│   ├── ai_providers_list_screen.dart
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── action_result_screen.dart
│   └── home_screen.dart
├── utils/
│   └── validators.dart      # Validierung der Formularfelder
└── main.dart                # MaterialApp.router + Umleitungen

assets/
└── logos/                   # Anbieter-Logos (SVG)
```

## Backend

Das Backend ist eine selbst gehostete [PocketBase](https://pocketbase.io)-Instanz
auf einem Server, erreichbar über einen Cloudflare Tunnel.

- API-Adresse: `https://app.devhorizon.online`
- Collection: `users` (eingebauter Typ `auth`)
- Endpunkte: `POST /api/collections/users/records` (Registrierung),
  `POST /api/collections/users/auth-with-password` (Anmeldung)

Die Adresse in einer einzigen Datei ändern:

```dart
// lib/core/config.dart
static const String baseUrl = 'https://your-domain.example';
```

### Namensfeld

Die eingebaute `users`-Collection von PocketBase hat **kein Feld `username`** —
stattdessen wird das Systemfeld `name` verwendet. Die App sendet und liest
genau dieses:

```dart
'name': username.trim()          // bei der Registrierung
json['name'] ?? json['username'] // beim Lesen
```

### API-Regeln der `users`-Collection

| Regel | Wert |
|---|---|
| List/Search | `@request.query.k = 'pb_av_1' && @request.query.q != '' && (email = @request.query.q \|\| name = @request.query.q)` |
| View | `- Superusers only` |
| Create | *(leer)* — Registrierung ist offen |
| Update | `@request.auth.id = id` |
| Delete | `- Superusers only` |

Die List/Search-Regel dient ausschließlich der Verfügbarkeitsprüfung. Die Anfrage

```text
GET /api/collections/users/records?k=pb_av_1&q=jemand@example.com
```

liefert höchstens einen Treffer und ist in allen anderen Fällen leer (ohne `k`,
ohne `q`, mit jedem anderen `filter`). Bedeutung von `totalItems`:

- `1` — der Wert ist belegt
- `0` — der Wert ist frei

Das Geheimnis des Parameters `k` (`AppConfig.availabilitySecret`, Name in
`AppConfig.availabilityParam`) schützt vor Massenabfragen.
Es lässt sich aus der APK extrahieren, schützt also vor zufälligem Scannen,
nicht aber vor einem gezielten Angreifer. Die Bedingung
`@request.query.q != ''` ist zwingend: ohne sie findet eine Anfrage ohne `q`
Datensätze mit leerem `name` oder leerem `email`. Das Feld `email` wird
zusätzlich durch die Antwort verborgen (`emailVisibility = false`) — nach
außen gelangt nur die Tatsache, dass das Konto existiert.

> ⚠️ Das Feld `name` ist **nicht eindeutig** (PocketBase kann keinen
> Unique-Index auf ein beliebiges Textfeld legen). Die Prüfung meldet
> „Belegt", der Server würde eine Duplikatannahme formal aber zulassen.
> Die Eindeutigkeit von `email` ist durch einen Index garantiert.

## Ergebnisbildschirme

Jeder Registrierungs- und Anmeldeversuch endet auf einem Ergebnisbildschirm
(`/register-result`, `/login-result`), der entweder die Erfolgsmeldung oder
die Fehlerbeschreibung anzeigt:

| Fall | Überschrift | Schaltflächen |
|---|---|---|
| Registrierung OK | Регистрация прошла успешно | Перейти к входу · Создать ещё один аккаунт |
| Registrierung fehlgeschlagen | Регистрация не выполнена | Попробовать снова · Перейти к входу |
| Anmeldung OK | Вход выполнен | Перейти в профиль |
| Anmeldung fehlgeschlagen | Вход не выполнен | Попробовать снова · Создать аккаунт |

Das Ergebnis wird über `actionResultProvider` weitergegeben, sodass ein
Umleiten während der Anfrage es nicht verlieren kann. Fehler werden auf den
Stapel *gepushd* — „Zurück" kehrt zum ausgefüllten Formular zurück.

## AI Providers list

Erreichbar vom Startbildschirm (`AI-провайдеры` → `/ai-providers`). Eine Karte
pro Anbieter, sortiert nach `fallbackPriority`. Jede Karte bietet:

- einen Ein-/Aus-Schalter
- `URL`, `Model`, `API Key` (maskiert) und `Fallback priority`
- Links zur Login-Seite und zur API-Key-Seite des Anbieters (`url_launcher`)
- `Редактировать` / `Удалить` (Löschen mit Bestätigung)
- ein Logo: `logoUrl` → `logoAsset` (`assets/logos/<name>.svg`) → generisches Icon

Neue Anbieter kommen über `Добавить провайдера` hinzu. Beim ersten Aufruf wird
die Liste mit beliebten Anbietern gefüllt (OpenAI, Anthropic, Google Gemini,
Groq, OpenRouter, Ollama, LM Studio, Mistral, Together, Fireworks).

### Speicherung: Konfiguration auf dem Server, Secrets auf dem Gerät

| Was | Wo |
|---|---|
| name, enabled, url, model, fallbackPriority, Links, Logo | PocketBase-Collection `ai_providers` |
| API-Key | `flutter_secure_storage`, Schlüssel `ai_provider_<userId>_<providerId>` |

Der API-Key verlässt das Gerät nie: `AiProvidersService` entfernt `api_key` aus
jeder Anfrage und liest ihn aus dem Secure Storage zurück. Der Key liegt also
weder in der Datenbank noch in Backups oder Server-Logs.

### API Rules für die Collection `ai_providers`

| Regel | Wert |
|---|---|
| List/Search | `@request.auth.id != '' && user = @request.auth.id` |
| View | `@request.auth.id != '' && user = @request.auth.id` |
| Create | `@request.auth.id != ''` |
| Update | `@request.auth.id != '' && user = @request.auth.id` |
| Delete | `@request.auth.id != '' && user = @request.auth.id` |

Felder: `user` (Relation → `users`, required), `name` (text, required),
`enabled` (bool), `url` (url, required), `model` (text, required),
`fallbackPriority` (number, min 0), `loginUrl`, `getApiKeyUrl`, `logoUrl` (url),
`logoAsset` (text), `isPredefined` (bool).

> Ein Feld `api_key` wird auf dem Server **nicht** benötigt — der Key liegt nur
> auf dem Gerät.

## Kompilieren

```bash
flutter pub get
flutter build apk --debug     # Test-APK
flutter build apk --release   # Release-APK (Benutzerkey erforderlich)
```

Die APK landet in `build/app/outputs/flutter-apk/`.

### Windows: pub-Cache auf einem anderen Laufwerk

Wenn Projekt und pub-Cache auf verschiedenen Windows-Laufwerken liegen (Projekt
auf `E:`, Cache auf `C:`), scheitert der inkrementelle Kotlin-Compiler mit
`this and base files have different roots`. Das ist bereits in
`android/gradle.properties` berücksichtigt:

```properties
kotlin.incremental=false
kotlin.incremental.useClasspathSnapshot=false
```

## Deployment (eigener PocketBase)

`deploy/` enthält alles, damit das Backend nicht mehr ausfällt:

| Datei | Zweck |
|---|---|
| `install-pocketbase-service.sh` | installiert PocketBase als systemd-Dienst (`Restart=always`, Autostart beim Boot) |
| `pocketbase.service` | Referenz-Unit für die manuelle Installation |
| `create-ai-providers-migration.js` | Migration, die die Collection `ai_providers` erstellt |
| `README.md` | Schritt-für-Schritt-Anleitung |

```bash
sudo ./deploy/install-pocketbase-service.sh
cp deploy/create-ai-providers-migration.js \
   ~/pocketbase/pb_migrations/1760313600_create_ai_providers.js
sudo systemctl restart pocketbase
```

Ohne den Dienst lebt PocketBase nur so lange wie die SSH-Sitzung, die es
gestartet hat — genau das machte die API zu einem 502.

## Tests

```bash
flutter test
```

Abgedeckt sind die Modelle, der Ergebnisbildschirm, der komplette Ablauf
Registrierung / Anmeldung / Abmelden sowie der AI-Provider-Ablauf (Add, Edit,
Toggle, Delete und die Garantie „der API-Key erreicht den Server nie").

Die Verfügbarkeitsprüfung gegen den echten Server ist optional:

```bash
flutter test test\availability_integration_test.dart --dart-define=PB_LIVE=true
```

## Erweiterungspunkt für soziale Anmeldung

In `lib/services/auth_service.dart`:

```dart
Future<void> signInWithGoogle() async {
  // TODO: Google OAuth in PocketBase aktivieren (Settings > Auth providers)
}
```

Anbieter in PocketBase aktivieren und diese Methode ausfüllen — mehr ist nicht
nötig, um die Google-Anmeldung ohne Umbau der Bildschürme hinzuzufügen.

## Lizenz

MIT
