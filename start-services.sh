#!/usr/bin/env bash
# =============================================================================
# start-services.sh — единая точка автозапуска при старте WSL2-VM.
# Указываем в /etc/wsl.conf:
#   [boot]
#   command=/home/sa/.dsh/bin/start-services.sh
#
# Поднимает (идемпотентно, по порядку):
#   1. LightRAG (база знаний, http://127.0.0.1:9621)
#   2. dsh web (GUI DeepSeek Harness, http://127.0.0.1:3080)
# =============================================================================
set -u
# [boot] command WSL запускает без пользовательского окружения: HOME не задан —
# восстанавливаем из passwd (без него все пути $HOME/... ломаются).
if [[ -z "${HOME:-}" ]]; then
  export HOME="$(getent passwd "$(id -un)" | cut -d: -f6)" 2>/dev/null || export HOME=/home/sa
fi

# [boot] command может запускаться от root (Docker Desktop первым поднимает
# дистрибутив с -u root). Сервисы должны работать от пользователя по умолчанию.
if [[ "$(id -u)" == "0" ]]; then
  default_user="$(awk -F= '/^\[user\]/{u=1;next} u&&/^default=/{print $2; exit}' /etc/wsl.conf 2>/dev/null | tr -d '[:space:]')"
  default_user="${default_user:-sa}"
  if id "$default_user" >/dev/null 2>&1; then
    echo "root: перезапуск от пользователя $default_user" >&2
    exec runuser -u "$default_user" -- "$0" "$@"
  fi
fi

# Диагностика: фиксация факта запуска boot-command и окружения.
# Отдельный файл на каждый запуск — чтобы разные идентичности
# (root/nobody/sa) не конфликтовали правами записи в общем файле.
bootdiag="/home/sa/.dsh/logs/boot-$(date +%Y%m%d-%H%M%S)-$(id -un).log"
{
  echo "$(date -Is) start-services invoked: $0"
  echo "  uid=$(id -u) user=$(id -un) HOME=${HOME:-<unset>}"
  echo "  PATH=$PATH"
} >> "$bootdiag" 2>/dev/null || true


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

status=0
if "$SCRIPT_DIR/lightrag-start.sh"; then :; else
  echo "WARNING: LightRAG не запущен (продолжаю)." >&2
  status=1
fi
if "$SCRIPT_DIR/dsh-web-start.sh"; then :; else
  echo "WARNING: dsh web не запущен." >&2
  status=1
fi
exit "$status"
