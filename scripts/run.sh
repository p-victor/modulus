#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

HOST_OS="$(uname -s)"

if [[ -f "build.conf" ]]; then
    source "build.conf"
fi
MODULE="${1:-${MODULE:-test_module}}"

if [[ "$HOST_OS" == "Linux" ]]; then
    EXEC="./build/linux_amd64/bin/modulus"
    MODULE_PATH="./build/linux_amd64/modules/${MODULE}.so"
else
    EXEC="./build/windows_amd64/bin/modulus.exe"
    MODULE_PATH="./build/windows_amd64/modules/${MODULE}.dll"
fi

if [[ ! -f "$EXEC" ]]; then
    echo "Executable not found: $EXEC"
    echo "Build first with: make build"
    exit 1
fi

if [[ ! -f "$MODULE_PATH" ]]; then
    echo "Module not found: $MODULE_PATH"
    echo "Build first with: make build"
    exit 1
fi

exec "$EXEC" "$MODULE_PATH"