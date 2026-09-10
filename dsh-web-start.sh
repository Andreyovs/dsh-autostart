#!/usr/bin/env bash
# =============================================================================
# dsh-web-start.sh — идемпотентный запуск DeepSeek Harness web (dsh web) в WSL.
#
# Режимы:
#   ./dsh-web-start.sh               — detached-запуск (nohup/setsid), если
#                                      сервис ещё не запущен; ожидает порт.
#                                      Для [boot] command= в /etc/wsl.conf
#                                      и для ручного запуска.
#   ./dsh-web-start.sh --foreground  — запуск в переднем плане (exec).
#                                      Для systemd-юнита (Type=simple).
#
# Переменные окружения (необязательные):
#   DSH_BIN          — явный путь к бинарнику dsh
#   DSH_WEB_PORT     — порт GUI (по умолчанию 3080)
#   DSH_WEB_LOG_DIR  — каталог логов (по умолчанию ~/.dsh/logs)
#
# Скрипт идемпотентен: если порт уже отдаёт HTTP, он ничего не запускает
# и завершается с кодом 0.
# =============================================================================
set -u
# [boot] command WSL запускает без пользовательского окружения: HOME не задан —
# восстанавливаем из passwd (без него все пути $HOME/... ломаются).
if [[ -z "${HOME:-}" ]]; then
  export HOME="$(getent passwd "$(id -un)" | cut -d: -f6)" 2>/dev/null || export HOME=/home/sa
fi


HOST=127.0.0.1
PORT="${DSH_WEB_PORT:-3080}"
LOG_DIR="${DSH_WEB_LOG_DIR:-$HOME/.dsh/logs}"
LOG_FILE="$LOG_DIR/dsh-web.log"
WAIT_SECONDS=60

log() { printf '%s %s\n' "$(date -Is)" "$*" >> "$LOG_FILE"; }

# --- Поиск бинарника dsh -----------------------------------------------------
# 1) $DSH_BIN, 2) PATH, 3) самая свежая копия в кэше npx (путь содержит
#    хэш версии, поэтому берём по времени изменения).
resolve_dsh() {
  if [[ -n "${DSH_BIN:-}" ]]; then
    [[ -x "$DSH_BIN" ]] && { printf '%s\n' "$DSH_BIN"; return 0; }
    return 1
  fi
  local cmd
  if cmd="$(command -v dsh 2>/dev/null)" && [[ -x "$cmd" ]]; then
    printf '%s\n' "$cmd"
    return 0
  fi
  local newest
  newest="$(ls -1dt "$HOME"/.npm/_npx/*/node_modules/.bin/dsh 2>/dev/null | head -n 1 || true)"
  if [[ -n "$newest" && -x "$newest" ]]; then
    printf '%s\n' "$newest"
    return 0
  fi
  return 1
}

# --- Проверка, запущен ли уже сервис -----------------------------------------
# Любой HTTP-ответ (даже 401) считается "сервис работает".
port_up() {
  if command -v curl >/dev/null 2>&1; then
    curl -s -o /dev/null -m 2 "http://$HOST:$PORT/"
  else
    (exec 3<>"/dev/tcp/$HOST/$PORT") 2>/dev/null && { exec 3>&- 3<&-; return 0; }
    return 1
  fi
}

wait_for_port() {
  local i
  for ((i = 0; i < WAIT_SECONDS; i++)); do
    port_up && return 0
    sleep 1
  done
  return 1
}

main() {
  local foreground=0
  [[ "${1:-}" == "--foreground" ]] && foreground=1

  if port_up; then
    echo "dsh web уже работает: http://$HOST:$PORT/ — ничего не запускаю."
    return 0
  fi

  local dsh
  if ! dsh="$(resolve_dsh)"; then
    echo "ОШИБКА: бинарник dsh не найден. Укажите DSH_BIN (путь) в окружении." >&2
    return 1
  fi

  mkdir -p "$LOG_DIR"

  if (( foreground )); then
    log "запуск (foreground): $dsh web"
    exec "$dsh" web
  fi

  log "запуск (detached): $dsh web"
  setsid nohup "$dsh" web >> "$LOG_FILE" 2>&1 < /dev/null &

  if wait_for_port; then
    log "успех: http://$HOST:$PORT/ отвечает"
    echo "dsh web запущен: http://$HOST:$PORT/ (лог: $LOG_FILE)"
    return 0
  fi

  log "ОШИБКА: порт $PORT не поднялся за ${WAIT_SECONDS}s"
  echo "ОШИБКА: dsh web не поднял порт $PORT за ${WAIT_SECONDS}s. См. $LOG_FILE" >&2
  return 1
}

main "$@"
