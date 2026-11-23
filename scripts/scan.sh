#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

IMAGE="${1:-task3-web:local}"
SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"
mkdir -p docs

args=(image --severity "$SEVERITY" --ignore-unfixed --exit-code 1 --no-progress "$IMAGE")

if command -v trivy >/dev/null 2>&1; then
    runner=(trivy)
else
    mkdir -p "$HOME/.cache/trivy"
    runner=(docker run --rm
        -v /var/run/docker.sock:/var/run/docker.sock
        -v "$HOME/.cache/trivy:/root/.cache/"
        aquasec/trivy:latest)
fi

echo "scanning $IMAGE for $SEVERITY vulnerabilities (unfixed ones ignored)"
"${runner[@]}" "${args[@]}" 2>&1 | tee docs/trivy-report.txt
echo "scan passed: no $SEVERITY findings in $IMAGE"
