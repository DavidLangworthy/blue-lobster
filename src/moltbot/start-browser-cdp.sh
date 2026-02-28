#!/bin/bash
# Launch a persistent local Chromium CDP process for OpenClaw attach-only mode.
set -euo pipefail

if [[ "${OPENCLAW_BROWSER_ATTACH_ONLY:-true}" != "true" ]]; then
  exit 0
fi

if [[ "${OPENCLAW_BROWSER_PRESTART:-true}" != "true" ]]; then
  exit 0
fi

CHROME_BIN="${OPENCLAW_BROWSER_BIN:-/usr/bin/chromium}"
CDP_PORT="${OPENCLAW_BROWSER_CDP_PORT:-18800}"
PROFILE_ROOT="${OPENCLAW_BROWSER_PROFILE_ROOT:-/tmp/openclaw-browser}"
USER_DATA_DIR="${PROFILE_ROOT}/openclaw/user-data"
LOG_FILE="${PROFILE_ROOT}/chromium.log"
PID_FILE="${PROFILE_ROOT}/chromium.pid"

mkdir -p "${USER_DATA_DIR}"

is_running() {
  if [[ -f "${PID_FILE}" ]]; then
    local pid
    pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

if is_running; then
  exit 0
fi

if command -v pgrep >/dev/null 2>&1; then
  pgrep -f "chromium.*--remote-debugging-port=${CDP_PORT}" >/dev/null 2>&1 && exit 0
fi

(
  while true; do
    "${CHROME_BIN}" \
      --headless \
      --no-sandbox \
      --disable-gpu \
      --disable-dev-shm-usage \
      --disable-setuid-sandbox \
      --no-first-run \
      --no-default-browser-check \
      --remote-debugging-address=127.0.0.1 \
      --remote-debugging-port="${CDP_PORT}" \
      --user-data-dir="${USER_DATA_DIR}" \
      about:blank >> "${LOG_FILE}" 2>&1 &
    echo "$!" > "${PID_FILE}"
    wait "$!" || true
    sleep 2
  done
) >/dev/null 2>&1 &

disown || true
