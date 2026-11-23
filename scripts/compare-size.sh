#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p docs

docker build -q -f extras/Dockerfile.single-stage -t task3-web:single-stage . >/dev/null
docker image inspect task3-web:local >/dev/null 2>&1 || docker compose build -q

size() {
    docker image inspect "$1" --format '{{.Size}}' | awk '{printf "%.0f MB", $1 / 1000000}'
}

user() {
    local u
    u=$(docker image inspect "$1" --format '{{.Config.User}}')
    echo "${u:-root}"
}

{
    printf '%-28s %-10s %s\n' IMAGE SIZE USER
    printf '%-28s %-10s %s\n' task3-web:single-stage "$(size task3-web:single-stage)" "$(user task3-web:single-stage)"
    printf '%-28s %-10s %s\n' task3-web:local "$(size task3-web:local)" "$(user task3-web:local)"
} | tee docs/image-size.txt
