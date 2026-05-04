#!/usr/bin/env bash
# Install selected desktop apps inside the container (no interactive menu).
# Usage:
#   docker run --rm -v "$PWD:/dotfiles:ro" -e ROOT=/dotfiles \
#     -e SMOKE_APPS=cloudflared dotfiles-smoke:fedora /usr/local/bin/smoke-install.sh
# SMOKE_APPS: comma-separated chrome,vscode,warp,cloudflared,cursor,discord
# Default: cloudflared (small; Fedora repo).

set -euo pipefail

ROOT="${ROOT:-/dotfiles}"
cd "$ROOT"

SMOKE_APPS="${SMOKE_APPS:-cloudflared}"

RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' NC=''
LOG_FILE="${TMPDIR:-/tmp}/dotfiles-smoke-install.log"
: >"$LOG_FILE"
DOTFILES_DIR="$ROOT"

log() { printf '%s\n' "$1" | tee -a "$LOG_FILE"; }
print_info() { log "${BLUE}[INFO]${NC} $1"; }
print_success() { log "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { log "${YELLOW}[WARNING]${NC} $1"; }
print_error() { log "${RED}[ERROR]${NC} $1"; }
print_header() {
    log "${MAGENTA}========================================${NC}"
    log "${MAGENTA} $1${NC}"
    log "${MAGENTA}========================================${NC}"
}

SCRIPT_DIR="$ROOT"
# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"
# shellcheck source=lib/repos.sh
source "$SCRIPT_DIR/lib/repos.sh"
# shellcheck source=lib/desktop-apps.sh
source "$SCRIPT_DIR/lib/desktop-apps.sh"

DISTRO=""
PACKAGE_MANAGER=""
INSTALL_CMD=""
UPDATE_CMD=""
declare -A APP_DICT

echo "== smoke-install: SMOKE_APPS=$SMOKE_APPS =="

detect_distro
init_app_dict

if ! desktop_apps_set_want_from_csv "$SMOKE_APPS"; then
    echo "== smoke-install: nothing valid in SMOKE_APPS; exit 1 ==" >&2
    exit 1
fi
for k in chrome vscode warp cloudflared cursor discord; do
    [[ "${DESKTOP_WANT[$k]:-}" == "1" ]] && echo "   + $k"
done

trap - ERR
if ! desktop_apps_install_selected; then
    print_error "smoke-install: desktop_apps_install_selected failed"
    exit 1
fi

print_success "smoke-install OK"
echo "== smoke-install OK (log: $LOG_FILE) =="
