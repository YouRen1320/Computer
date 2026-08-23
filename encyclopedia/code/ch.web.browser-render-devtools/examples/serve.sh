#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="serve"
if [[ "${1:-}" == "--check" ]]; then
  MODE="check"
  shift
fi
PORT="${1:-4173}"

if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1024 || PORT > 65535 )); then
  printf 'STATIC_SERVER_ERROR invalid-port=%s expected=1024..65535\n' "$PORT" >&2
  exit 2
fi

if command -v python3 >/dev/null 2>&1; then
  BACKEND="python3"
elif command -v ruby >/dev/null 2>&1; then
  BACKEND="ruby"
elif command -v jwebserver >/dev/null 2>&1; then
  BACKEND="jwebserver"
else
  printf 'STATIC_SERVER_ERROR no-supported-backend expected=python3-or-ruby-or-jwebserver\n' >&2
  exit 2
fi

printf 'STATIC_SERVER_READY bind=127.0.0.1 port=%s root=%s backend=%s\n' \
  "$PORT" "$ROOT_DIR/public" "$BACKEND"
if [[ "$MODE" == "check" ]]; then
  exit 0
fi

case "$BACKEND" in
  python3)
    exec python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$ROOT_DIR/public"
    ;;
  ruby)
    exec ruby -run -e httpd -- "$ROOT_DIR/public" -p "$PORT" -b 127.0.0.1
    ;;
  jwebserver)
    exec jwebserver -b 127.0.0.1 -p "$PORT" -d "$ROOT_DIR/public" -o none
    ;;
esac
