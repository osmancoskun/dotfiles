#!/usr/bin/env bash
# Smoke test inside container: syntax-check + distro detect + init_app_dict.
# Does not run dnf/apt update, menus, or stow. Safe for CI / Docker.

set -euo pipefail

ROOT="${ROOT:-/dotfiles}"
cd "$ROOT"

echo "== Smoke: ROOT=$ROOT =="

echo "== bash -n setup.sh =="
bash -n setup.sh

echo "== bash -n lib/*.sh tui/*.sh =="
shopt -s nullglob
for f in lib/*.sh tui/*.sh; do
    [[ -f "$f" ]] || continue
    echo "   $f"
    bash -n "$f"
done

echo "== detect_distro + init_app_dict (no sudo) =="
# Minimal stubs — same names as setup.sh logging (no tee to avoid HOME issues).
RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' NC=''
LOG_FILE="${TMPDIR:-/tmp}/dotfiles-smoke.log"
: >"$LOG_FILE"
DOTFILES_DIR="$ROOT"

log() { printf '%s\n' "$1" | tee -a "$LOG_FILE" >/dev/null; }
print_info() { log "[INFO] $1"; echo "[INFO] $1"; }
print_success() { log "[SUCCESS] $1"; echo "[SUCCESS] $1"; }
print_warning() { log "[WARNING] $1"; echo "[WARNING] $1"; }
print_error() { log "[ERROR] $1"; echo "[ERROR] $1" >&2; }
print_header() { log "=== $1 ==="; echo "=== $1 ==="; }

error_handler() { echo "[ERR] line $1" >&2; exit 1; }
trap 'error_handler $LINENO' ERR

SCRIPT_DIR="$ROOT"
# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"

DISTRO=""
PACKAGE_MANAGER=""
INSTALL_CMD=""
UPDATE_CMD=""
declare -A APP_DICT

detect_distro
init_app_dict

echo "== Result: DISTRO=$DISTRO PACKAGE_MANAGER=$PACKAGE_MANAGER =="
[[ -n "$DISTRO" ]]
[[ -n "${APP_DICT[git]:-}" ]]

trap - ERR
echo "== Smoke OK =="
