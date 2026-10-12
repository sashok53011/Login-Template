# Деплой PocketBase

Всё, что нужно, чтобы `https://app.devhorizon.online` перестал отдавать 502 и
больше не падал.

## Почему падало

PocketBase запускался вручную в терминале:

```bash
./pocketbase serve --http=127.0.0.1:8090 --dir=./pb_data
```

Процесс — дочерний для SSH-сессии. Закрыл терминал или перезагрузил сервер —
процесс умер, а `cloudflared` (он-то как раз в автозапуске) продолжал
проксировать на `127.0.0.1:8090`, где уже никто не слушал. Отсюда 502 и
«Host Error» в браузере.

## Шаг 1. PocketBase в автозапуск

Скопируй на сервер папку `deploy/` и выполни:

```bash
cd deploy
chmod +x install-pocketbase-service.sh
sudo ./install-pocketbase-service.sh
```

Скрипт сам найдёт каталог с `pocketbase` (или возьми его из аргумента:
`sudo ./install-pocketbase-service.sh /home/sashok5301/pocketbase`), создаст
юнит `/etc/systemd/system/pocketbase.service` с `Restart=always`, включит
автозапуск и покажет результат health-check.

Проверка:

```bash
systemctl status pocketbase --no-pager
journalctl -u pocketbase -n 30 --no-pager
curl -sS http://127.0.0.1:8090/api/health; echo
curl -sS -o /dev/null -w "%{http_code}\n" https://app.devhorizon.online/api/health
```

Ожидаемо: `active (running)`, `{"message":"API is healthy."}`, и **200** снаружи.

> Если копируешь скрипт с Windows, проверь переводы строк: bash ругается
> `bad interpreter: /usr/bin/env bash^M`, если в файле CRLF. Лечится за секунду:
> `sed -i 's/\r$//' install-pocketbase-service.sh`

## Шаг 2. Коллекция `ai_providers`

Экран «AI Providers list» в приложении работает с коллекцией `ai_providers`.
Скопируй миграцию и перезапусти сервис:

```bash
cp create-ai-providers-migration.js \
   ~/pocketbase/pb_migrations/1760313600_create_ai_providers.js

sudo systemctl restart pocketbase
journalctl -u pocketbase -n 30 --no-pager
```

Миграция идемпотентна: если коллекция уже есть, она ничего не сделает.
Обратный откат — нажать `migrate down` или просто удалить коллекцию в админке.

Проверка:

```bash
curl -sS -o /dev/null -w "%{http_code}\n" \
  http://127.0.0.1:8090/api/collections/ai_providers/records
```

`200` — коллекция на месте (`403` тоже означает, что коллекция существует, но
закрыта правилами от анонимных запросов — это правильно).

## Что создаётся

| Поле | Тип | Примечание |
|---|---|---|
| `user` | relation → `users` | required, владелец записи |
| `name` | text | required |
| `enabled` | bool | вкл/выкл провайдера |
| `url` | url | required |
| `model` | text | required |
| `fallbackPriority` | number | min 0, сортировка списка |
| `loginUrl` | url | ссылка на страницу логина провайдера |
| `getApiKeyUrl` | url | ссылка на получение API-ключа |
| `logoUrl` | url | кастомный логотип |
| `logoAsset` | text | имя файла из `assets/logos` |
| `isPredefined` | bool | из предзаполненного списка |

Правила доступа:

| Правило | Значение |
|---|---|
| List/Search | `@request.auth.id != '' && user = @request.auth.id` |
| View | `@request.auth.id != '' && user = @request.auth.id` |
| Create | `@request.auth.id != ''` |
| Update | `@request.auth.id != '' && user = @request.auth.id` |
| Delete | `@request.auth.id != '' && user = @request.auth.id` |

> **API-ключи на сервере не хранятся.** Поля `api_key` в коллекции нет
> специально: клиент вырезает ключ из любого запроса, а сам ключ лежит в
> `flutter_secure_storage` на телефоне.

## Если сервис не поднимается

```bash
journalctl -u pocketbase -n 50 --no-pager
```

Частые причины:

- `WorkingDirectory`/`ExecStart` указывают не туда — поправь юнит и
  `sudo systemctl daemon-reload && sudo systemctl restart pocketbase`;
- нет прав на `pb_data` — `sudo chown -R sashok5301:users ~/pocketbase/pb_data`;
- порт 8090 занят старым процессом — `sudo pkill -f 'pocketbase serve'`,
  затем `sudo systemctl restart pocketbase`.
