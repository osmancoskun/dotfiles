#!/usr/bin/env bash
# Build smoke image(s) and run with repo mounted read-only.
# Usage:
#   ./docker/run-smoke.sh [fedora|debian|arch|all]
#   ./docker/run-smoke.sh fedora-install   # all apps (chrome,vscode,warp,cloudflared,cursor,discord) unless SMOKE_APPS is set
#   SMOKE_APPS=cloudflared ./docker/run-smoke.sh debian-install

set -euo pipefail

cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd)"
TARGET="${1:-fedora}"

run_one() {
    local name=$1
    local file="docker/Dockerfile.${name}"
    local tag="dotfiles-smoke:${name}"
    echo ">>> build $tag ($file)"
    docker build -f "$file" -t "$tag" "$REPO_ROOT"
    echo ">>> run $tag"
    docker run --rm -v "$REPO_ROOT:/dotfiles:ro" -e ROOT=/dotfiles "$tag"
    echo ">>> OK $name"
}

run_install() {
    local name=$1
    local file="docker/Dockerfile.${name}"
    local tag="dotfiles-smoke:${name}"
    local apps="${SMOKE_APPS:-}"
    if [[ -z "$apps" ]]; then
        if [[ "$name" == "fedora" ]]; then
            apps="chrome,vscode,warp,cloudflared,cursor,discord"
        else
            apps="cloudflared"
        fi
    fi
    echo ">>> build $tag ($file)"
    docker build -f "$file" -t "$tag" "$REPO_ROOT"
    echo ">>> run install $tag (SMOKE_APPS=$apps)"
    docker run --rm -v "$REPO_ROOT:/dotfiles:ro" \
        -e ROOT=/dotfiles \
        -e "SMOKE_APPS=$apps" \
        --entrypoint /usr/local/bin/smoke-install.sh \
        "$tag"
    echo ">>> OK ${name}-install"
}

case "$TARGET" in
    fedora) run_one fedora ;;
    debian) run_one debian ;;
    arch) run_one arch ;;
    all)
        run_one fedora
        run_one debian
        run_one arch
        ;;
    fedora-install) run_install fedora ;;
    debian-install) run_install debian ;;
    arch-install) run_install arch ;;
    *)
        echo "Usage: $0 [fedora|debian|arch|all|fedora-install|debian-install|arch-install]" >&2
        exit 1
        ;;
esac
