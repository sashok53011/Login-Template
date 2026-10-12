#!/usr/bin/env bash
#
# Installs PocketBase as a systemd service so that it
#   - starts automatically on boot, and
#   - keeps running after the SSH session is closed.
#
# That is exactly what broke production: `./pocketbase serve ...` was started
# by hand in a terminal, so the process died with the session and
# https://app.devhorizon.online started answering 502.
#
# Usage:
#   sudo ./install-pocketbase-service.sh                 # autodetect
#   sudo ./install-pocketbase-service.sh /home/me/pb     # explicit directory
#
set -euo pipefail

SERVICE_NAME="pocketbase"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
HOST="127.0.0.1"
PORT="8090"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Запусти через sudo: sudo $0 $*" >&2
  exit 1
fi

# The user that owns PocketBase (the one that called sudo), not root.
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_GROUP="$(id -gn "${TARGET_USER}")"
TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"

# ---------------------------------------------------------------- locate dir
PB_DIR="${1:-}"
if [[ -z "${PB_DIR}" ]]; then
  for candidate in \
    "${TARGET_HOME}/pocketbase" \
    "${TARGET_HOME}/pb" \
    "${TARGET_HOME}/apps/pocketbase" \
    /opt/pocketbase; do
    if [[ -x "${candidate}/pocketbase" ]]; then
      PB_DIR="${candidate}"
      break
    fi
  done
fi

if [[ -z "${PB_DIR}" || ! -x "${PB_DIR}/pocketbase" ]]; then
  echo "Не нашёл исполняемый файл pocketbase." >&2
  echo "Передай папку явно, например: sudo $0 ${TARGET_HOME}/pocketbase" >&2
  exit 1
fi

if [[ ! -d "${PB_DIR}/pb_data" ]]; then
  echo "Внимание: ${PB_DIR}/pb_data не найдена — PocketBase создаст пустую базу." >&2
fi

echo "Каталог:  ${PB_DIR}"
echo "Пользователь: ${TARGET_USER}:${TARGET_GROUP}"

# ------------------------------------------------------------------ stop old
systemctl stop "${SERVICE_NAME}" 2>/dev/null || true

# ------------------------------------------------------------------- install
cat >"${SERVICE_FILE}" <<EOF
[Unit]
Description=PocketBase
Documentation=https://pocketbase.io/docs/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${TARGET_USER}
Group=${TARGET_GROUP}
WorkingDirectory=${PB_DIR}
ExecStart=${PB_DIR}/pocketbase serve --http=${HOST}:${PORT} --dir=${PB_DIR}/pb_data
Restart=always
RestartSec=3
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

chown -R "${TARGET_USER}:${TARGET_GROUP}" "${PB_DIR}/pb_data" 2>/dev/null || true

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}" >/dev/null
systemctl restart "${SERVICE_NAME}"

sleep 2

# -------------------------------------------------------------------- verify
echo
systemctl status "${SERVICE_NAME}" --no-pager --lines=5 || true
echo
echo -n "health (local):  "
curl -sS --max-time 5 "http://${HOST}:${PORT}/api/health" || echo "нет ответа"
echo
echo -n "health (public): "
curl -sS --max-time 10 -o /dev/null -w "%{http_code}\n" \
  "https://app.devhorizon.online/api/health" || echo "нет ответа"
echo
echo "Готово. Логи: journalctl -u ${SERVICE_NAME} -f"
