#!/usr/bin/env bash
# =============================================================================
# lightrag-start.sh — идемпотентный запуск локального сервера LightRAG в WSL.
#
# Сервер: /home/sa/work/lightrag (venv из GitHub: HKUDS/LightRAG, [api]).
# LLM/эмбеддинги: gpustack (настроено в /home/sa/work/lightrag/.env).
#
# Идемпотентен: если /health уже отвечает — ничего не запускает.
# Переменные окружения (необязательные):
#   LIGHTRAG_PORT — порт (по умолчанию 9621)
# =============================================================================
set -u
# [boot] command WSL запускает без пользовательского окружения: HOME не задан —
# восстанавливаем из passwd (без него все пути $HOME/... ломаются).
if [[ -z "${HOME:-}" ]]; then
  export HOME="$(getent passwd "$(id -un)" | cut -d: -f6)" 2>/dev/null || export HOME=/home/sa
fi


HOST=127.0.0.1
PORT="${LIGHTRAG_PORT:-9621}"
ROOT="${LIGHTRAG_ROOT:-$HOME/work/lightrag}"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/lightrag-server.log"
WAIT_SECONDS=90

health_up() {
  if command -v curl >/dev/null 2>&1; then
    curl -s -o /dev/null -m 2 "http://$HOST:$PORT/health"
  else
    (exec 3<>"/dev/tcp/$HOST/$PORT") 2>/dev/null && { exec 3>&- 3<&-; return 0; }
    return 1
  fi
}

main() {
  if health_up; then
    echo "LightRAG уже запущен: http://$HOST:$PORT/health — ничего не запускаю."
    return 0
  fi

  if [[ ! -x "$ROOT/.venv/bin/lightrag-server" ]]; then
    echo "ОШИБКА: $ROOT/.venv/bin/lightrag-server не найден (venv не установлен?)." >&2
    return 1
  fi

  mkdir -p "$LOG_DIR" "$ROOT/inputs" "$ROOT/rag_storage"
  echo "$(date -Is) starting lightrag-server (log: $LOG_FILE)" >> "$LOG_FILE"

  # cwd = $ROOT, чтобы lightrag-server подхватил .env из корневого каталога
  cd "$ROOT" || return 1
  setsid nohup "$ROOT/.venv/bin/lightrag-server" >> "$LOG_FILE" 2>&1 < /dev/null &

  local i
  for ((i = 0; i < WAIT_SECONDS; i++)); do
    if health_up; then
      echo "$(date -Is) lightrag-server healthy: http://$HOST:$PORT" >> "$LOG_FILE"
      echo "LightRAG запущен: http://$HOST:$PORT (лог: $LOG_FILE)"
      return 0
    fi
    sleep 1
  done

  echo "ОШИБКА: lightrag-server не поднял /health за ${WAIT_SECONDS}s. См. $LOG_FILE" >&2
  return 1
}

main "$@"
