#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET="${1:-all}"
MODE="${2:-clean}"

clean_contents() {
    local dir="$1"
    mkdir -p "$dir/bin" "$dir/modules" "$dir/temp" "$dir/logs"
    rm -rf "$dir/bin"/*
    rm -rf "$dir/modules"/*
    rm -rf "$dir/temp"/*
    rm -rf "$dir/logs"/*
}

nuke_dir() {
    local dir="$1"
    rm -rf "$dir"
}

act_on_target() {
    local dir="$1"

    if [[ "$MODE" == "nuke" ]]; then
        echo "Removing $dir"
        nuke_dir "$dir"
    else
        echo "Cleaning $dir"
        clean_contents "$dir"
    fi
}

case "$TARGET" in
    all)
        act_on_target "build/linux_amd64"
        act_on_target "build/windows_amd64"
        ;;
    linux|linux_amd64)
        act_on_target "build/linux_amd64"
        ;;
    windows|windows_amd64|win)
        act_on_target "build/windows_amd64"
        ;;
    *)
        echo "Unknown target: $TARGET"
        echo "Usage: $0 [all|linux|windows] [clean|nuke]"
        exit 1
        ;;
esac

echo "Done."