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
