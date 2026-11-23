#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

say() { echo "[setup] $*"; }
die() { echo "[setup] error: $*" >&2; exit 1; }

command -v docker >/dev/null || die "docker is not installed"
docker compose version >/dev/null 2>&1 || die "docker compose plugin is not installed"
docker info >/dev/null 2>&1 || die "cannot reach the docker daemon (is it running, is your user in the docker group?)"

if [ -f .env ]; then
    say ".env exists, not overwriting"
else
    pw=$(openssl rand -hex 16 2>/dev/null || head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
    sed "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$pw/" .env.example > .env
    chmod 600 .env
    say "created .env with a generated database password"
fi

mkdir -p docs
chmod +x scripts/*.sh

say "building image"
docker compose build

say "scanning the image before starting anything"
bash scripts/scan.sh task3-web:local

say "starting the stack"
docker compose up -d --wait

say "running checks"
bash scripts/verify.sh | tee docs/verify-output.txt

say "done"
