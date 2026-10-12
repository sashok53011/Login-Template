# Деплой PocketBase

Всё, что нужно для `https://app.devhorizon.online`: сам PocketBase, коллекция
провайдеров, веб-страница `/ai-providers/` и её API.

## Почему падало

PocketBase запускался вручную в терминале, поэтому умирал вместе с SSH-сессией.
Ещё была ловушка: user-юнит `~/.config/systemd/user/pocketbase.service` с
`Linger=no` — он живёт только пока открыта сессия пользователя. Оба варианта
заменены одним системным юнитом.

Проверка состояния:

```bash
systemctl is-active pocketbase
systemctl is-enabled pocketbase
curl -sS http://127.0.0.1:8090/api/health; echo
curl -sS -o /dev/null -w "%{http_code}\n" https://app.devhorizon.online/api/health
```

## Шаг 1. PocketBase в автозапуск

```bash
sudo ./install-pocketbase-service.sh                 # автопоиск каталога
sudo ./install-pocketbase-service.sh /home/USER/pb   # или явно
```

Скрипт создаёт `/etc/systemd/system/pocketbase.service` с `Restart=always`,
включает автозапуск и сразу печатает результат health-check.

> Если копируешь скрипт с Windows — проверь переводы строк, иначе bash ругается
> `bad interpreter: /usr/bin/env bash^M`: `sed -i 's/\r$//' install-pocketbase-service.sh`

## Шаг 2. Коллекция `ai_providers` (не обязательна)

> Начиная с версии с каталогом приложение **не использует** эту коллекцию:
> провайдеры теперь приходят из `catalogue.json`. Миграция оставлена для
> совместимости и для старых сборок; на работу текущей версии она не влияет.

```bash
cp create-ai-providers-migration.js \
   ~/pocketbase/pb_migrations/1791463000_create_ai_providers.js
sudo systemctl restart pocketbase
```

Идемпотентно: если коллекция уже есть, ничего не произойдёт.

## Шаг 3. Защита от утечки в правиле `users`

```bash
cp tighten-users-list-rule.js \
   ~/pocketbase/pb_migrations/1791463100_tighten_users_list_rule.js
sudo systemctl restart pocketbase
```

Добавляет `@request.query.q != ''` в List/Search правило. Без него запрос без
параметра `q` отдавал записи с пустым `name`/`email`.

Проверка (ожидается `totalItems: 0`):

```bash
curl -sS -G http://127.0.0.1:8090/api/collections/users/records \
  --data "k=pb_av_1" --data "perPage=1"
```

## Шаг 4. Каталог провайдеров, веб-страница и API

Файлы из `pb_hooks/` и `pb_public/` копируются в каталог PocketBase:

```bash
cp -r pb_hooks/*  ~/pocketbase/pb_hooks/
cp -r pb_public/* ~/pocketbase/pb_public/
sudo systemctl restart pocketbase
```

### Модель доступа

Каталог провайдеров — один общий файл, который правит **только superuser
PocketBase**. Обычный пользователь не может добавлять, править или удалять
провайдеров: он лишь включает нужные и хранит свои API-ключи на устройстве.

| Файл | Кто пишет | Что внутри |
|---|---|---|
| `pb_data/ai-config/catalogue.json` | только superuser | определения провайдеров + `status: active \| dead` |
| `pb_data/ai-config/<userId>.json` | сам пользователь | только флаги `enabled` (права 0600) |

| Маршрут | Кто | Что делает |
|---|---|---|
| `GET /api/ai-config` | вход + superuser | каталог с флагами пользователя, поле `canEdit` |
| `PUT /api/ai-config` | superuser | заменяет каталог |
| `PUT /api/ai-config` | обычный пользователь | сохраняет **только** флаги `enabled`; всё остальное игнорируется, а провайдеры вне каталога отбрасываются |
| `DELETE /api/ai-config` | обычный пользователь | сбрасывает свои флаги |
| `GET /api/ai-config/meta` | вход + superuser | диагностика, `isSuperuser` |
| `GET /api/ai-stats` | вход + superuser | статистика проверок по всем провайдерам каталога |
| `POST /api/ai-stats` | вход + superuser | записать результат проверки; для `dead`-провайдера — 403 |

### Статистика проверок

Приложение проверяет провайдера запросом к его `/models` с ключом пользователя
(это же и проверка ключа) и сразу отправляет результат на сервер. Хранится по
файлу на провайдера:

```text
pb_data/ai-stats/<providerId>.json
```

Внутри — счётчики по каждой модели, включая разбивку по пользователям. Наружу
сырые данные пользователей не отдаются: API возвращает только итоги
(`ok`, `fail`, `usersOk`, `usersFail`, `last`, `lastStatus`, `lastError`).

Успехом считается только случай, когда ключ принят **и** провайдер предлагает
настроенную модель. Провайдер, помеченный `dead`, не тестируется: кнопка в
приложении выключена, а сервер отвечает `403` на попытку записать результат.

Веб-страница обновляет статистику опросом раз в 8 секунд.

Поле `status: dead` — это «след, что провайдер умер». Такой провайдер исчезает
у пользователей, **у которых он выключен**; включённые не трогаются, чтобы
человек не терял свою настройку. Администратор всегда видит все записи, чтобы
снять пометку.

### Первичное наполнение каталога

```bash
cp catalogue.json ~/pocketbase/pb_data/ai-config/catalogue.json
sudo systemctl restart pocketbase
```

В `catalogue.json` уже лежат 10 популярных провайдеров со `status: active`.

### Веб-страница

`https://app.devhorizon.online/ai-providers/` — та же страница для обеих ролей:

* **обычный пользователь**: вход по своему аккаунту, переключатели
  «включить/выключить», без кнопок правки;
* **администратор**: в форме входа галочка «Вход администратора (superuser)» —
  после неё доступны добавление, правка, удаление и поле статуса.

**API-ключей на сервере нет ни в одном из режимов.** Сервер отбрасывает поле
`api_key`, даже если прислать его руками, и это же проверяет тест.

Проверка с токеном:

```bash
TOKEN=$(curl -sS -X POST http://127.0.0.1:8090/api/collections/users/auth-with-password \
  -H 'Content-Type: application/json' \
  -d '{"identity":"YOU@example.com","password":"..."}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["token"])')

curl -sS -H "Authorization: $TOKEN" http://127.0.0.1:8090/api/ai-config; echo
```

### ⚠️ Ловушка JSVM: обработчики изолированы

Обработчики маршрутов в PocketBase выполняются **в изолированном контексте** и
не видят область видимости своего файла. Такой код молча падает с
`ReferenceError: <имя> is not defined` и отдаёт 400 на любой запрос, хотя сам
файл загружается без ошибок:

```js
// ТАК НЕ РАБОТАЕТ
function helper() { return 1 }
routerAdd("GET", "/api/x", (e) => e.json(200, { v: helper() }), $apis.requireAuth());
```

Правильно — подключать модуль через `require()` **внутри** обработчика:

```js
// ТАК РАБОТАЕТ
routerAdd("GET", "/api/x", (e) => {
  const lib = require(__hooks + "/ai-config-lib.js");
  return e.json(200, lib.something());
}, $apis.requireAuth());
```

Поэтому логика лежит в `pb_hooks/ai-config-lib.js` (обычный `.js`, PocketBase
его как хук не грузит), а `ai-config.pb.js` — только регистрация маршрутов.

Ошибки хуков не попадают в `journalctl`: смотри их так:

```bash
python3 - <<'PY'
import sqlite3, json
con = sqlite3.connect('/home/USER/pocketbase/pb_data/auxiliary.db')
for created, level, message, data in con.execute(
        "select created, level, message, data from _logs order by created desc limit 10"):
    print('=====', created, level, '|', message)
    if data:
        d = json.loads(data)
        if 'error' in d:
            print('   error:', d['error'])
PY
```

## Что создаётся

Запись каталога (`catalogue.json`), она же — форма ответа `/api/ai-config`:

| Поле | Тип | Примечание |
|---|---|---|
| `id` | text | идентификатор, например `openai` |
| `name` | text | обязательное |
| `url` | text | endpoint провайдера |
| `model` | text | модель по умолчанию |
| `fallbackPriority` | number | порядок в списке |
| `loginUrl` | text | страница логина провайдера |
| `getApiKeyUrl` | text | получение API-ключа |
| `logoUrl` | text | кастомный логотип (ссылка) |
| `logoAsset` | text | имя файла из `assets/logos` |
| `status` | `active` \| `dead` | «провайдер умер»: у пользователей с выключенным он исчезает |
| `enabled` | bool | **только для чтения**: приходит из флагов пользователя |

Поля `enabled` в каталоге нет — она относится к пользователю, а не к провайдеру.

## Где что лежит на сервере

```text
~/pocketbase/
├── pocketbase                  бинарник
├── pb_data/
│   ├── data.db                 база
│   ├── auxiliary.db            логи
│   └── ai-config/
│       ├── catalogue.json      каталог провайдеров (правит superuser)
│       └── <userId>.json       флаги «включён» (по файлу на пользователя)
├── pb_data/ai-stats/
│   └── <providerId>.json       статистика проверок по моделям
├── pb_migrations/              применённые миграции
├── pb_hooks/
│   ├── ai-config.pb.js         маршруты /api/ai-config
│   ├── ai-config-lib.js        логика (подключается через require)
│   ├── ai-stats.pb.js          маршруты /api/ai-stats
│   └── ai-stats-lib.js         статистика (тоже через require)
└── pb_public/
    └── ai-providers/           веб-страница
```

## Если что-то не так

```bash
sudo systemctl status pocketbase --no-pager
sudo journalctl -u pocketbase -n 50 --no-pager
```

Частые причины:

- `bind: address already in use` — где-то живёт второй PocketBase:
  `pkill -x pocketbase` и `sudo systemctl restart pocketbase`;
- нет прав на `pb_data` — `sudo chown -R USER:users ~/pocketbase/pb_data`;
- маршрут отдаёт 400, хотя файл загрузился — см. ловушку JSVM выше;
- пустая страница `/ai-providers/` — проверь `pb_public/ai-providers/index.html`
  и очисти кэш браузера (ассеты подключены с `?v=`, при правке подними версию).
