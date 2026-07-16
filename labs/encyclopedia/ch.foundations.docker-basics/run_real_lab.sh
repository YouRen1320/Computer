#!/bin/sh
set -eu

if [ "${ALLOW_FACTORYCARE_DOCKER_LAB:-}" != "1" ]; then
  echo "Refusing real Docker changes. Set ALLOW_FACTORYCARE_DOCKER_LAB=1 after reading this script." >&2
  exit 2
fi

if [ -z "${FACTORYCARE_DOCKER_IMAGE:-}" ]; then
  echo "FACTORYCARE_DOCKER_IMAGE must name an already-local image containing python3." >&2
  exit 2
fi
case "$FACTORYCARE_DOCKER_IMAGE" in
  -*|*[!A-Za-z0-9._/:@-]*)
    echo "FACTORYCARE_DOCKER_IMAGE contains unsupported characters." >&2
    exit 2
    ;;
esac

HOST_PORT=${FACTORYCARE_DOCKER_HOST_PORT:-18080}
case "$HOST_PORT" in
  *[!0-9]*|'')
    echo "FACTORYCARE_DOCKER_HOST_PORT must be numeric." >&2
    exit 2
    ;;
esac
if [ "$HOST_PORT" -lt 1024 ] || [ "$HOST_PORT" -gt 65535 ]; then
  echo "FACTORYCARE_DOCKER_HOST_PORT must be in 1024..65535." >&2
  exit 2
fi

command -v docker >/dev/null 2>&1 || {
  echo "docker CLI is unavailable." >&2
  exit 3
}
command -v curl >/dev/null 2>&1 || {
  echo "curl is unavailable." >&2
  exit 3
}

docker version >/dev/null 2>&1 || {
  echo "Docker daemon is unavailable; the offline model remains runnable." >&2
  exit 3
}
docker image inspect "$FACTORYCARE_DOCKER_IMAGE" >/dev/null 2>&1 || {
  echo "The requested image is not local. This lab never pulls it." >&2
  exit 3
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXAMPLE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../../examples/encyclopedia/ch.foundations.docker-basics" && pwd)
PREFIX="fc-basics-$$"
LAB_IMAGE="$PREFIX-image:local"
NETWORK="$PREFIX-net"
VOLUME="$PREFIX-data"
CONTAINERS="$PREFIX-wrong $PREFIX-check $PREFIX-writer $PREFIX-api-a $PREFIX-probe $PREFIX-api-b $PREFIX-api-c $PREFIX-ephemeral $PREFIX-ephemeral-check $PREFIX-bind-writer"

for name in $CONTAINERS; do
  if docker container inspect "$name" >/dev/null 2>&1; then
    echo "Refusing to reuse existing container $name." >&2
    exit 4
  fi
done
if docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo "Refusing to reuse existing network $NETWORK." >&2
  exit 4
fi
if docker volume inspect "$VOLUME" >/dev/null 2>&1; then
  echo "Refusing to reuse existing volume $VOLUME." >&2
  exit 4
fi
if docker image inspect "$LAB_IMAGE" >/dev/null 2>&1; then
  echo "Refusing to reuse existing image $LAB_IMAGE." >&2
  exit 4
fi

CREATED_IMAGE=0
CREATED_NETWORK=0
CREATED_VOLUME=0
BIND_DIR=""
CLEANED=0

cleanup() {
  if [ "$CLEANED" -eq 1 ]; then
    return
  fi
  CLEANED=1
  set +e
  for name in $CONTAINERS; do
    if docker container inspect "$name" >/dev/null 2>&1; then
      running=$(docker container inspect --format '{{.State.Running}}' "$name" 2>/dev/null)
      if [ "$running" = "true" ]; then
        docker container stop --time 3 "$name" >/dev/null
      fi
      docker container rm "$name" >/dev/null
    fi
  done
  if [ "$CREATED_VOLUME" -eq 1 ] && docker volume inspect "$VOLUME" >/dev/null 2>&1; then
    docker volume rm "$VOLUME" >/dev/null
  fi
  if [ "$CREATED_NETWORK" -eq 1 ] && docker network inspect "$NETWORK" >/dev/null 2>&1; then
    docker network rm "$NETWORK" >/dev/null
  fi
  if [ "$CREATED_IMAGE" -eq 1 ] && docker image inspect "$LAB_IMAGE" >/dev/null 2>&1; then
    docker image rm "$LAB_IMAGE" >/dev/null
  fi
  if [ -n "$BIND_DIR" ] && [ -f "$BIND_DIR/host-visible.txt" ]; then
    rm "$BIND_DIR/host-visible.txt"
  fi
  if [ -n "$BIND_DIR" ] && [ -d "$BIND_DIR" ]; then
    rmdir "$BIND_DIR"
  fi
  set -e
}
trap cleanup EXIT INT TERM

docker build --pull=false \
  --build-arg "BASE_IMAGE=$FACTORYCARE_DOCKER_IMAGE" \
  --tag "$LAB_IMAGE" \
  --file "$EXAMPLE_DIR/Dockerfile.local" \
  "$EXAMPLE_DIR" >/dev/null
CREATED_IMAGE=1

docker network create "$NETWORK" >/dev/null
CREATED_NETWORK=1
docker volume create "$VOLUME" >/dev/null
CREATED_VOLUME=1

docker container run --name "$PREFIX-wrong" --pull=never \
  --mount "type=volume,src=$VOLUME,dst=/wrong" \
  --entrypoint python3 "$LAB_IMAGE" -c \
  'from pathlib import Path; Path("/srv/factorycare").mkdir(parents=True, exist_ok=True); Path("/srv/factorycare/runtime.txt").write_text("wrong-layer", encoding="utf-8")' >/dev/null
docker container rm "$PREFIX-wrong" >/dev/null

WRONG_RESULT=$(docker container run --name "$PREFIX-check" --pull=never \
  --mount "type=volume,src=$VOLUME,dst=/srv/factorycare" \
  --entrypoint python3 "$LAB_IMAGE" -c \
  'from pathlib import Path; print(Path("/srv/factorycare/runtime.txt").exists())')
docker container rm "$PREFIX-check" >/dev/null
if [ "$WRONG_RESULT" != "False" ]; then
  echo "Wrong-target oracle failed: data unexpectedly reached the volume." >&2
  exit 5
fi

docker container run --name "$PREFIX-writer" --pull=never \
  --mount "type=volume,src=$VOLUME,dst=/srv/factorycare" \
  --entrypoint python3 "$LAB_IMAGE" -c \
  'from pathlib import Path; Path("/srv/factorycare/index.html").write_text("volume-persisted", encoding="utf-8")' >/dev/null
docker container rm "$PREFIX-writer" >/dev/null

docker container run --detach --name "$PREFIX-api-a" --pull=never \
  --network "$NETWORK" \
  --mount "type=volume,src=$VOLUME,dst=/srv/factorycare" \
  --entrypoint python3 "$LAB_IMAGE" -m http.server 8080 --directory /srv/factorycare >/dev/null

if curl --silent --show-error --fail --max-time 2 "http://127.0.0.1:$HOST_PORT" >/dev/null 2>&1; then
  echo "Unpublished-port oracle failed: host unexpectedly reached the service." >&2
  exit 5
fi

docker container run --name "$PREFIX-probe" --pull=never --network "$NETWORK" \
  --entrypoint python3 "$LAB_IMAGE" -c \
  "import time, urllib.request
for attempt in range(20):
    try:
        body = urllib.request.urlopen('http://$PREFIX-api-a:8080', timeout=1).read().decode()
        raise SystemExit(0 if 'volume-persisted' in body else 7)
    except Exception:
        time.sleep(0.1)
raise SystemExit(8)" >/dev/null
docker container rm "$PREFIX-probe" >/dev/null
docker container stop --time 3 "$PREFIX-api-a" >/dev/null
docker container rm "$PREFIX-api-a" >/dev/null

docker container run --detach --name "$PREFIX-api-b" --pull=never \
  --network "$NETWORK" \
  --publish "127.0.0.1:$HOST_PORT:8080" \
  --mount "type=volume,src=$VOLUME,dst=/srv/factorycare" \
  --entrypoint python3 "$LAB_IMAGE" -m http.server 8080 --directory /srv/factorycare >/dev/null

BODY=""
attempt=0
while [ "$attempt" -lt 20 ]; do
  if BODY=$(curl --silent --show-error --fail --max-time 1 "http://127.0.0.1:$HOST_PORT" 2>/dev/null); then
    break
  fi
  attempt=$((attempt + 1))
  sleep 0.1
done
case "$BODY" in
  *volume-persisted*) ;;
  *)
    echo "Published-port or volume oracle failed." >&2
    exit 5
    ;;
esac
docker container stop --time 3 "$PREFIX-api-b" >/dev/null
docker container rm "$PREFIX-api-b" >/dev/null

docker container run --detach --name "$PREFIX-api-c" --pull=never \
  --network "$NETWORK" \
  --publish "127.0.0.1:$HOST_PORT:8080" \
  --mount "type=volume,src=$VOLUME,dst=/srv/factorycare" \
  --entrypoint python3 "$LAB_IMAGE" -m http.server 8080 --directory /srv/factorycare >/dev/null
sleep 0.2
curl --silent --show-error --fail --max-time 2 "http://127.0.0.1:$HOST_PORT" | grep 'volume-persisted' >/dev/null

docker container run --detach --name "$PREFIX-ephemeral" --pull=never \
  --entrypoint python3 "$LAB_IMAGE" -c \
  'from pathlib import Path; import time; Path("/tmp/fc-state").write_text("temporary", encoding="utf-8"); time.sleep(600)' >/dev/null
docker container exec "$PREFIX-ephemeral" python3 -c \
  'from pathlib import Path; raise SystemExit(0 if Path("/tmp/fc-state").exists() else 9)'
docker container stop --time 3 "$PREFIX-ephemeral" >/dev/null
docker container rm "$PREFIX-ephemeral" >/dev/null
docker container run --name "$PREFIX-ephemeral-check" --pull=never \
  --entrypoint python3 "$LAB_IMAGE" -c \
  'from pathlib import Path; raise SystemExit(0 if not Path("/tmp/fc-state").exists() else 9)'
docker container rm "$PREFIX-ephemeral-check" >/dev/null

BIND_DIR=$(mktemp -d "${TMPDIR:-/tmp}/fc-basics-bind.XXXXXX")
docker container run --name "$PREFIX-bind-writer" --pull=never \
  --mount "type=bind,src=$BIND_DIR,dst=/exchange" \
  --entrypoint python3 "$LAB_IMAGE" -c \
  'from pathlib import Path; Path("/exchange/host-visible.txt").write_text("bind-visible", encoding="utf-8")' >/dev/null
docker container rm "$PREFIX-bind-writer" >/dev/null
grep 'bind-visible' "$BIND_DIR/host-visible.txt" >/dev/null

cleanup
for name in $CONTAINERS; do
  if docker container inspect "$name" >/dev/null 2>&1; then
    echo "Cleanup left container $name." >&2
    exit 6
  fi
done
docker network inspect "$NETWORK" >/dev/null 2>&1 && exit 6
docker volume inspect "$VOLUME" >/dev/null 2>&1 && exit 6
docker image inspect "$LAB_IMAGE" >/dev/null 2>&1 && exit 6

echo "docker-basics real daemon verification: PASS"
