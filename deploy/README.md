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

## Шаг 2. Коллекция `ai_providers`

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

## Шаг 4. Веб-страница и общий конфиг

Файлы из `pb_hooks/` и `pb_public/` копируются в каталог PocketBase:

```bash
cp -r pb_hooks/*  ~/pocketbase/pb_hooks/
cp -r pb_public/* ~/pocketbase/pb_public/
sudo systemctl restart pocketbase
```

Что получается:

| URL | Что это |
|---|---|
| `/ai-providers/` | веб-версия списка: вход, регистрация, выход, добавление и правка провайдеров |
| `GET/PUT /api/ai-config` | общий конфиг текущего пользователя, требует токен |

Конфиг лежит в `pb_data/ai-config/<userId>.json` (права 0600), по одному файлу
на пользователя. **API-ключей там нет** — они живут только на устройстве в
`flutter_secure_storage`, а сервер отбрасывает поле `api_key`, даже если его
прислать руками.

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

Коллекция `ai_providers`:

| Поле | Тип | Примечание |
|---|---|---|
| `user` | relation → `users` | required, владелец записи |
| `name` | text | required |
| `enabled` | bool | вкл/выкл провайдера |
| `url` | url | required |
| `model` | text | required |
| `fallbackPriority` | number | min 0, сортировка списка |
| `loginUrl` | url | страница логина провайдера |
| `getApiKeyUrl` | url | получение API-ключа |
| `logoUrl` | url | кастомный логотип |
| `logoAsset` | text | имя файла из `assets/logos` |
| `isPredefined` | bool | из предзаполненного списка |

Правила доступа: `@request.auth.id != '' && user = @request.auth.id` для
List/View/Update/Delete, `@request.auth.id != ''` для Create.

## Где что лежит на сервере

```text
~/pocketbase/
├── pocketbase                  бинарник
├── pb_data/
│   ├── data.db                 база
│   ├── auxiliary.db            логи
│   └── ai-config/<userId>.json общий конфиг (по файлу на пользователя)
├── pb_migrations/              применённые миграции
├── pb_hooks/
│   ├── ai-config.pb.js         маршруты /api/ai-config
│   └── ai-config-lib.js        логика (подключается через require)
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
