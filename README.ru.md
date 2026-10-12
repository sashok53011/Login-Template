> [English](README.md) · **Русский** · [Deutsch](README.de.md)

# Login Template (Flutter + PocketBase)

Шаблон Android-приложения с авторизацией: **регистрация**, **вход**, **выход** и экран
`Вы зашли как ...` после успешного входа.

## Функционал

- Регистрация: `email + username + password + confirm password`
- Требования к паролю с живым чек-листом (минимум 8 символов, пароли совпадают)
- Экран результата после регистрации и входа: подтверждение успеха или описание ошибки, для регистрации — кнопка «Перейти к входу»
- Живая проверка занятости email и username (занят / свободен прямо при вводе)
- Вход по `email + password`
- Автологин при старте приложения (восстановление сессии)
- Хранение токена в `flutter_secure_storage`
- Экран главной страницы: `Вы зашли как <username / email / id>`
- Выход из аккаунта с подтверждением
- Splash-экран, пока восстанавливается сессия
- Задел под Google OAuth (метод `signInWithGoogle()` в `auth_service.dart`)
- **AI Providers list** (после входа): вкл/выкл, редактирование URL / model /
  API-ключа / fallback priority, логотипы провайдеров, ссылки на страницу
  логина и получения ключа, add / edit / delete

## Стек

| Пакет | Назначение |
| --- | --- |
| `dio` | HTTP-клиент для REST API |
| `flutter_riverpod` | управление состоянием |
| `go_router` | навигация + маршрутизация по статусу авторизации |
| `flutter_secure_storage` | безопасное хранение токена и API-ключей провайдеров |
| `equatable` | сравнение моделей |
| `url_launcher` | открытие страниц логина / получения ключа |
| `flutter_svg` | логотипы провайдеров из `assets/logos` |

## Структура

```
lib/
├── core/
│   ├── config.dart          # baseUrl и имя коллекции
│   └── constants.dart       # ключи хранилища
├── models/
│   ├── action_result.dart   # результат последней попытки входа/регистрации
│   ├── ai_provider.dart     # конфигурация AI-провайдера
│   └── user.dart            # модель пользователя + displayName
├── providers/
│   ├── action_result_provider.dart
│   ├── ai_providers_provider.dart # провайдеры + список популярных
│   └── auth_provider.dart   # AuthNotifier + провайдеры Riverpod
├── services/
│   ├── ai_providers_service.dart  # CRUD коллекции ai_providers
│   ├── api_client.dart      # Dio + авторизационный заголовок
│   ├── auth_service.dart    # register / login / logout / проверка доступности
│   └── secure_storage_service.dart
├── screens/
│   ├── ai_providers_list_screen.dart
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── action_result_screen.dart
│   └── home_screen.dart
├── utils/
│   └── validators.dart      # валидация полей форм
└── main.dart                # MaterialApp.router + редиректы

assets/
└── logos/                   # логотипы провайдеров (SVG)
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
| List/Search | `@request.query.k = 'pb_av_1' && @request.query.q != '' && (email = @request.query.q \|\| name = @request.query.q)` |
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

Секретное значение параметра `k` (`AppConfig.availabilitySecret`, имя —
`AppConfig.availabilityParam`) защищает от массового перебора.
Из APK его можно извлечь, поэтому это защита от случайного сканирования,
а не от целенаправленной атаки. Защита `@request.query.q != ''` обязательна:
без неё запрос без `q` находит записи с пустыми `name` или `email`.
Поле `email` дополнительно скрыто ответом
(`emailVisibility = false`) — наружу утекает только факт существования.

> ⚠️ Поле `name` **не уникально** (PocketBase не умеет unique-индекс для
> произвольного text-поля). Проверка покажет «Занят», но сервер дубликат
> формально пропустит. Уникальность `email` гарантируется индексом.

## Экраны результата

Каждая попытка регистрации или входа заканчивается экраном результата
(`/register-result`, `/login-result`), на котором либо подтверждение успеха,
либо описание ошибки:

| Случай | Заголовок | Кнопки |
|---|---|---|
| Регистрация ОК | Регистрация прошла успешно | Перейти к входу · Создать ещё один аккаунт |
| Регистрация не удалась | Регистрация не выполнена | Попробовать снова · Перейти к входу |
| Вход ОК | Вход выполнен | Перейти в профиль |
| Вход не удался | Вход не выполнен | Попробовать снова · Создать аккаунт |

Результат передаётся через `actionResultProvider`, поэтому редирект,
срабатывающий во время запроса, его не теряет. Ошибка **пушится** в стек —
нажатие «Назад» возвращает к заполненной форме.

## AI Providers list

Доступен с главного экрана (`AI-провайдеры` → `/ai-providers`). По карточке на
провайдера, сортировка по `fallbackPriority`. В карточке:

- переключатель вкл/выкл
- `URL`, `Model`, `API Key` (маской) и `Fallback priority`
- ссылки на страницу логина провайдера и на страницу получения ключа (`url_launcher`)
- `Редактировать` / `Удалить` (удаление с подтверждением)
- логотип: `logoUrl` → `logoAsset` (`assets/logos/<имя>.svg`) → запасная иконка

Новый провайдер добавляется кнопкой `Добавить провайдера`. При первом заходе
список наполняется популярными (OpenAI, Anthropic, Google Gemini, Groq,
OpenRouter, Ollama, LM Studio, Mistral, Together, Fireworks).

### Хранение: конфиг на сервере, секреты на устройстве

| Что | Где |
|---|---|
| name, enabled, url, model, fallbackPriority, ссылки, логотип | Коллекция PocketBase `ai_providers` |
| API-ключ | `flutter_secure_storage`, ключ `ai_provider_<userId>_<providerId>` |

API-ключ не покидает устройство: `AiProvidersService` вырезает `api_key` из
любого запроса и читает ключ обратно из secure storage. Поэтому ключа нет ни в
базе, ни в бэкапах, ни в логах сервера.

### API Rules коллекции `ai_providers`

| Правило | Значение |
|---|---|
| List/Search | `@request.auth.id != '' && user = @request.auth.id` |
| View | `@request.auth.id != '' && user = @request.auth.id` |
| Create | `@request.auth.id != ''` |
| Update | `@request.auth.id != '' && user = @request.auth.id` |
| Delete | `@request.auth.id != '' && user = @request.auth.id` |

Поля: `user` (relation → `users`, required), `name` (text, required),
`enabled` (bool), `url` (url, required), `model` (text, required),
`fallbackPriority` (number, min 0), `loginUrl`, `getApiKeyUrl`, `logoUrl` (url),
`logoAsset` (text), `isPredefined` (bool).

> Поле `api_key` на сервере **не нужно** — ключ хранится только на устройстве.

## Сборка

```bash
flutter pub get
flutter build apk --debug     # тестовый APK
flutter build apk --release   # релизный APK (нужен keystore)
```

APK появится в `build/app/outputs/flutter-apk/`.

### Windows: кэш pub на другом диске

Если проект и кэш pub лежат на разных дисках Windows (например, проект на `E:`,
кэш на `C:`), инкрементальный компилятор Kotlin падает с ошибкой
`this and base files have different roots`. Это уже учтено в
`android/gradle.properties`:

```properties
kotlin.incremental=false
kotlin.incremental.useClasspathSnapshot=false
```

## Деплой (свой PocketBase)

В `deploy/` лежит всё, чтобы бэкенд больше не падал:

| Файл | Назначение |
|---|---|
| `install-pocketbase-service.sh` | ставит PocketBase как systemd-сервис (`Restart=always`, автозапуск при загрузке) |
| `pocketbase.service` | эталонный юнит для ручной установки |
| `create-ai-providers-migration.js` | миграция, создающая коллекцию `ai_providers` |
| `README.md` | пошаговая инструкция |

```bash
sudo ./deploy/install-pocketbase-service.sh
cp deploy/create-ai-providers-migration.js \
   ~/pocketbase/pb_migrations/1760313600_create_ai_providers.js
sudo systemctl restart pocketbase
```

Без сервиса PocketBase живёт ровно столько, сколько живёт запустившая его
SSH-сессия — именно из-за этого API отдавал 502.

## Тесты

```bash
flutter test
```

Покрыты модели, экран результата, полный цикл регистрация / вход / выход и
поток AI-провайдеров (add, edit, toggle, delete и гарантия «API-ключ не уходит
на сервер»).

Проверка доступности на живом сервере — по флагу:

```bash
flutter test test\availability_integration_test.dart --dart-define=PB_LIVE=true
```

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
