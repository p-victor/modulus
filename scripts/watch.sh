#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f "build.conf" ]]; then
    source "build.conf"
fi

if [[ "${MODULUS_HOT_RELOAD:-false}" != "true" ]]; then
    echo "watch: MODULUS_HOT_RELOAD is not enabled in build.conf — nothing to watch"
    exit 1
fi

if ! command -v inotifywait &>/dev/null; then
    echo "watch: inotifywait not found — install inotify-tools"
    echo "  sudo apt install inotify-tools"
    exit 1
fi

echo "==> Watching modules/ for .odin changes (Ctrl-C to stop)"

inotifywait -m -r -e close_write -e moved_to --include '\.odin$' modules/ 2>/dev/null \
| while read -r dir _event file; do
    # Extract module name from path: "modules/test_module/" -> "test_module"
    module="${dir#modules/}"
    module="${module%%/*}"
    echo "==> $file changed in '$module', rebuilding..."
    make build-module MODULE="$module"
done
