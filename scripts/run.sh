#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

HOST_OS="$(uname -s)"

if [[ "$HOST_OS" == "Linux" ]]; then
    EXEC="./build/linux_amd64/bin/modulus"
else
    EXEC="./build/windows_amd64/bin/modulus.exe"
fi

if [[ ! -f "$EXEC" ]]; then
    echo "Executable not found: $EXEC"
    echo "Build first with: make build"
    exit 1
fi

exec "$EXEC"