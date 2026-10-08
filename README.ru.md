> [English](README.md) · **Русский** · [Deutsch](README.de.md)

# Login Template (Flutter + PocketBase)

Шаблон Android-приложения с авторизацией: **регистрация**, **вход**, **выход** и экран
`Вы зашли как ...` после успешного входа.

## Функционал

- Регистрация: `email + username + password + confirm password`
- Требования к паролю с живым чек-листом (минимум 8 символов, пароли совпадают)
- Экран «Регистрация прошла успешно» с кнопкой «Перейти к входу»
- Ошибки сервера выводятся прямо в форме регистрации
- Живая проверка занятости email и username (занят / свободен прямо при вводе)
- Вход по `email + password`
- Автологин при старте приложения (восстановление сессии)
- Хранение токена в `flutter_secure_storage`
- Экран главной страницы: `Вы зашли как <username / email / id>`
- Выход из аккаунта с подтверждением
- Splash-экран, пока восстанавливается сессия
- Задел под Google OAuth (метод `signInWithGoogle()` в `auth_service.dart`)

## Стек

| Пакет | Назначение |
| --- | --- |
| `dio` | HTTP-клиент для REST API |
| `flutter_riverpod` | управление состоянием |
| `go_router` | навигация + маршрутизация по статусу авторизации |
| `flutter_secure_storage` | безопасное хранение токена |
| `equatable` | сравнение моделей |

## Структура

```
lib/
├── core/
│   ├── config.dart          # baseUrl и имя коллекции
│   └── constants.dart       # ключи хранилища
├── models/
│   └── user.dart            # модель пользователя + displayName
├── providers/
│   └── auth_provider.dart   # AuthNotifier + провайдеры Riverpod
├── services/
│   ├── api_client.dart      # Dio + авторизационный заголовок
│   ├── auth_service.dart    # register / login / logout / проверка доступности
│   └── secure_storage_service.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── register_success_screen.dart
│   └── home_screen.dart
├── utils/
│   └── validators.dart      # валидация полей форм
└── main.dart                # MaterialApp.router + редиректы
```

## Бэкенд

Бэкенд — самописный [PocketBase](https://pocketbase.io) на сервере, доступный
через Cloudflare Tunnel.

- Адрес API: `https://app.devhorizon.online`
- Коллекция: `users` (встроенный тип `auth`)
- Эндпоинты: `POST /api/collections/users/records` (регистрация),
  `POST /api/collections/users/auth-with-password` (вход)

Смена адреса — один файл:

```dart
// lib/core/config.dart
static const String baseUrl = 'https://your-domain.example';
```

### Поле имени

Во встроенной коллекции `users` PocketBase **нет поля `username`** — для имени
используется системное поле `name`. Приложение отправляет и читает именно его:

```dart
'name': username.trim()          // при регистрации
json['name'] ?? json['username'] // при чтении
```

### API Rules коллекции `users`

| Правило | Значение |
|---|---|
| List/Search | `@request.query.k = 'pb_av_1' && (email = @request.query.q \|\| name = @request.query.q)` |
| View | `- Superusers only` |
| Create | *(пусто)* — регистрация открыта |
| Update | `@request.auth.id = id` |
| Delete | `- Superusers only` |

Правило List/Search нужно только для проверки занятости. Запрос

```text
GET /api/collections/users/records?k=pb_av_1&q=someone@mail.ru
```

возвращает максимум одно совпадение и пусто во всех остальных случаях
(без `k`, без `q`, с любым другим `filter`). Соответствие `totalItems`:

- `1` — значение занято
- `0` — свободно

Секрет `k` (`AppConfig.availabilityKey`) защищает от массового перебора.
Из APK его можно извлечь, поэтому это защита от случайного сканирования,
а не от целенаправленной атаки. Поле `email` дополнительно скрыто ответом
(`emailVisibility = false`) — наружу утекает только факт существования.

> ⚠️ Поле `name` **не уникально** (PocketBase не умеет unique-индекс для
> произвольного text-поля). Проверка покажет «Занят», но сервер дубликат
> формально пропустит. Уникальность `email` гарантируется индексом.

## Сборка

```bash
flutter pub get
flutter build apk --debug     # тестовый APK
flutter build apk --release   # релизный APK (нужен keystore)
```

APK появится в `build/app/outputs/flutter-apk/`.

## Точка расширения под соцсети

В `lib/services/auth_service.dart`:

```dart
Future<void> signInWithGoogle() async {
  // TODO: включить Google OAuth в PocketBase (Settings > Auth providers)
}
```

Включение провайдера в PocketBase + заполнение этого метода — этого
достаточно, чтобы добавить вход через Google без переработки экранов.

## Лицензия

MIT
