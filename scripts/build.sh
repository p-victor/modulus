#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET="${1:-native}"

HOST_OS="$(uname -s)"
HOST_ARCH="$(uname -m)"

normalize_target() {
    case "$1" in
        native)
            if [[ "$HOST_OS" == "Linux" ]]; then
                echo "linux_amd64"
            else
                echo "windows_amd64"
            fi
            ;;
        linux|linux_amd64)
            echo "linux_amd64"
            ;;
        windows|windows_amd64|win)
            echo "windows_amd64"
            ;;
        *)
            echo "Unknown target: $1" >&2
            exit 1
            ;;
    esac
}

TARGET="$(normalize_target "$TARGET")"

case "$TARGET" in
    linux_amd64)
        EXE_PATH="build/linux_amd64/bin/modulus"
        MODULE_PATH="build/linux_amd64/modules/test_module.so"
        ODIN_TARGET="linux_amd64"
        ;;
    windows_amd64)
        EXE_PATH="build/windows_amd64/bin/modulus.exe"
        MODULE_PATH="build/windows_amd64/modules/test_module.dll"
        ODIN_TARGET="windows_amd64"
        ;;
    *)
        echo "Unsupported target: $TARGET" >&2
        exit 1
        ;;
esac

mkdir -p "build/$TARGET/bin"
mkdir -p "build/$TARGET/modules"
mkdir -p "build/$TARGET/temp"
mkdir -p "build/$TARGET/logs"

echo "==> Building module for $TARGET"
odin build modules/test_module \
    -build-mode:dll \
    -collection:mod=. \
    -target:$ODIN_TARGET \
    -out:"$MODULE_PATH"

echo "==> Building engine for $TARGET"
odin build . \
    -collection:mod=. \
    -target:$ODIN_TARGET \
    -out:"$EXE_PATH"

echo "==> Build complete"
echo "    exe:    $EXE_PATH"
echo "    module: $MODULE_PATH"