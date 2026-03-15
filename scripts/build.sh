#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET="${1:-native}"
MODE="${2:-debug}"
STEP="${3:-all}" # all | module | engine

HOST_OS="$(uname -s)"
HOST_ARCH="$(uname -m)"

# Save env-provided MODULE before sourcing build.conf (which would overwrite it).
_MODULE_ENV="${MODULE:-}"

# Load flag defaults from build.conf, then allow env var overrides.
if [[ -f "build.conf" ]]; then
    source "build.conf"
fi
MODULUS_DEBUG="${MODULUS_DEBUG:-true}"
MODULUS_HOT_RELOAD="${MODULUS_HOT_RELOAD:-true}"
MODULUS_SAFE="${MODULUS_SAFE:-false}"

# Env var takes precedence over build.conf.
[[ -n "$_MODULE_ENV" ]] && MODULE="$_MODULE_ENV"
MODULE="${MODULE:-test_module}"

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
        MODULE_PATH="build/linux_amd64/modules/${MODULE}.so"
        ODIN_TARGET="linux_amd64"
        ;;
    windows_amd64)
        EXE_PATH="build/windows_amd64/bin/modulus.exe"
        MODULE_PATH="build/windows_amd64/modules/${MODULE}.dll"
        ODIN_TARGET="windows_amd64"
        ;;
    *)
        echo "Unsupported target: $TARGET" >&2
        exit 1
        ;;
esac

case "$MODE" in
    release)
        # Release forces all feature flags off regardless of build.conf.
        MODULUS_DEBUG=false
        MODULUS_HOT_RELOAD=false
        MODULUS_SAFE=false
        ODIN_OPT="-o:aggressive -no-bounds-check"
        ;;
    safe)
        # Safe: no logging, no hot-reload, but bounds checks and engine_assert stay on.
        MODULUS_DEBUG=false
        MODULUS_HOT_RELOAD=false
        MODULUS_SAFE=true
        ODIN_OPT="-o:speed"
        ;;
    debug|*)
        ODIN_OPT="-debug"
        ;;
esac

ODIN_FLAGS="$ODIN_OPT \
    -define:MODULUS_DEBUG=${MODULUS_DEBUG} \
    -define:MODULUS_HOT_RELOAD=${MODULUS_HOT_RELOAD} \
    -define:MODULUS_SAFE=${MODULUS_SAFE}"

mkdir -p "build/$TARGET/bin"
mkdir -p "build/$TARGET/modules"
mkdir -p "build/$TARGET/temp"
mkdir -p "build/$TARGET/logs"

if [[ "$STEP" != "engine" ]]; then
    echo "==> Building module '$MODULE' for $TARGET ($MODE)"
    odin build "modules/${MODULE}" \
        -build-mode:dll \
        -collection:mod=. \
        -target:$ODIN_TARGET \
        -out:"$MODULE_PATH" \
        $ODIN_FLAGS
fi

if [[ "$STEP" != "module" ]]; then
    echo "==> Building engine for $TARGET ($MODE)"
    odin build . \
        -collection:mod=. \
        -target:$ODIN_TARGET \
        -out:"$EXE_PATH" \
        $ODIN_FLAGS
fi

echo "==> Build complete"
echo "    exe:    $EXE_PATH"
echo "    module: $MODULE_PATH"