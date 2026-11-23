#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

set -a
. ./.env
set +a

port="${WEB_PORT:-8000}"
image="task3-web:local"
pass=0
fail=0

check() {
    local desc=$1
    shift
    if "$@" >/dev/null 2>&1; then
        echo "[ok]   $desc"
        pass=$((pass + 1))
    else
        echo "[fail] $desc"
        fail=$((fail + 1))
    fi
}

check_not() {
    local desc=$1
    shift
    if "$@" >/dev/null 2>&1; then
        echo "[fail] $desc"
        fail=$((fail + 1))
    else
        echo "[ok]   $desc"
        pass=$((pass + 1))
    fi
}

published_ports() {
    docker inspect -f '{{range $p, $b := .NetworkSettings.Ports}}{{if $b}}{{$p}} {{end}}{{end}}' "$(docker compose ps -q "$1")"
}

echo "== containers"
docker compose ps
echo
echo "== image"
docker image ls "$image"
echo
echo "== checks"
check "image is set to run as 10001:10001, not root" test "$(docker image inspect "$image" --format '{{.Config.User}}')" = "10001:10001"
check "web process runs as uid 10001" test "$(docker compose exec -T web id -u)" = "10001"
check "web container has no Linux capabilities" docker compose exec -T web sh -c 'grep -Eq "CapEff:[[:space:]]*0+$" /proc/self/status'
check_not "web root filesystem is read-only" docker compose exec -T web touch /srv/probe
check "backend network is internal" test "$(docker network inspect task3_backend --format '{{.Internal}}')" = "true"
check "db publishes no ports to the host" test -z "$(published_ports db)"
check_not "nothing listens on host port 5432" bash -c 'ss -ltn | grep -q ":5432 "'
check "web reaches db by name over the private network" docker compose exec -T web python -c "import socket; socket.create_connection(('db', 5432), 3)"
check_not "db has no outbound internet access" docker compose exec -T db wget -q -T 3 -O /dev/null http://example.com
check "health endpoint reports database up" bash -c "curl -fsS http://127.0.0.1:$port/health | grep -Eq '\"database\": ?\"up\"'"
check "app writes to the database" bash -c "curl -fsS http://127.0.0.1:$port/ | grep -q visits"
check "info endpoint reports uid 10001" bash -c "curl -fsS http://127.0.0.1:$port/info | grep -Eq '\"uid\": ?10001'"

echo
echo "== sample responses"
curl -fsS "http://127.0.0.1:$port/"
curl -fsS "http://127.0.0.1:$port/info"

echo
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
