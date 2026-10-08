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

## Stack

| Paket | Zweck |
| --- | --- |
| `dio` | HTTP-Client für die REST-API |
| `flutter_riverpod` | Zustandsverwaltung |
| `go_router` | Navigation + Routing nach Anmeldestatus |
| `flutter_secure_storage` | Sichere Speicherung des Tokens |
| `equatable` | Vergleich von Modellen |

## Struktur

```
lib/
├── core/
│   ├── config.dart          # baseUrl und Collection-Name
│   └── constants.dart       # Speicherschlüssel
├── models/
│   ├── action_result.dart   # Ergebnis der letzten Registrierungs-/Anmeldeversuche
│   └── user.dart            # Benutzermodell + displayName
├── providers/
│   ├── action_result_provider.dart
│   └── auth_provider.dart   # AuthNotifier + Riverpod-Provider
├── services/
│   ├── api_client.dart      # Dio + Auth-Header
│   ├── auth_service.dart    # register / login / logout / Verfügbarkeit
│   └── secure_storage_service.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── action_result_screen.dart
│   └── home_screen.dart
├── utils/
│   └── validators.dart      # Validierung der Formularfelder
└── main.dart                # MaterialApp.router + Umleitungen
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
| List/Search | `@request.query.k = 'pb_av_1' && (email = @request.query.q \|\| name = @request.query.q)` |
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

Das Geheimnis `k` (`AppConfig.availabilityKey`) schützt vor Massenabfragen.
Es lässt sich aus der APK extrahieren, schützt also vor zufälligem Scannen,
nicht aber vor einem gezielten Angreifer. Das Feld `email` wird zusätzlich
durch die Antwort verborgen (`emailVisibility = false`) — nach außen gelangt
nur die Tatsache, dass das Konto existiert.

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

## Kompilieren

```bash
flutter pub get
flutter build apk --debug     # Test-APK
flutter build apk --release   # Release-APK (Benutzerkey erforderlich)
```

Die APK landet in `build/app/outputs/flutter-apk/`.

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
