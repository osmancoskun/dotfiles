# Third-party / vendor installers (not distro default repos): Chrome, VS Code, WARP, cloudflared, Cursor, Discord.
# Vendor .repo / apt sources are added here only when an app needs them — no separate “enable all repos” step.
# For git, nc, Node from mirrors use repo-packages.sh (menu step 2).
# Expects: DISTRO, APP_DICT, print_*, install_package, numbered_prompt_apply_line_to_want, tui_read_with_back, TUI_BACK_TO_MAIN,
#          setup_third_party_repos,
#          setup_cloudflare_warp_repo, setup_cursor_repo, setup_rpmfusion_nonfree_fedora.

declare -gA DESKTOP_WANT=()

# Fill DESKTOP_WANT from comma-separated keys (same as SMOKE_APPS / menu selections).
# Unknown tokens are skipped with a warning. Returns 1 if no valid key remains.
desktop_apps_set_want_from_csv() {
    local csv=${1:-}
    DESKTOP_WANT=()
    [[ -z "$csv" ]] && return 1
    local _p
    IFS=',' read -ra _parts <<< "$csv"
    for _p in "${_parts[@]}"; do
        _p="${_p//[$'\t\r\n ']/}"
        [[ -z "$_p" ]] && continue
        case "$_p" in
            chrome | vscode | warp | cloudflared | cursor | discord)
                DESKTOP_WANT["$_p"]=1
                ;;
            *)
                print_warning "Unknown application key '$_p' (ignored)."
                ;;
        esac
    done
    local any=0
    for k in chrome vscode warp cloudflared cursor discord; do
        [[ "${DESKTOP_WANT[$k]:-}" == "1" ]] && any=1
    done
    (( any )) || return 1
    return 0
}

_desktop_in_container() {
    [[ -f /run/.containerenv ]] || [[ -f /.dockerenv ]]
}

desktop_apps_prompt_selection() {
    DESKTOP_WANT=()
    print_header "SELECT APPLICATIONS"
    print_info "Native / .rpm / .deb / AUR only — Flatpak is not used."

    local keys=(chrome vscode warp cloudflared cursor discord)
    local labels=(
        "Google Chrome (stable)"
        "Visual Studio Code"
        "Cloudflare WARP (warp-cli)"
        "cloudflared"
        "Cursor"
        "Discord"
    )
    local max=${#keys[@]}
    local i
    print_info ""
    for ((i = 0; i < max; i++)); do
        print_info "  $((i + 1))) ${labels[i]}"
    done
    print_info "  0) All listed above"
    print_info ""
    print_info "Type the numbers you want (spaces or commas), then Enter — e.g. 1 3 6"
    print_info "B) Back to main menu"
    local line=
    tui_read_with_back "> " line || return $?

    numbered_prompt_apply_line_to_want "$line" "$max" DESKTOP_WANT "${keys[@]}"

    local any=0
    for k in chrome vscode warp cloudflared cursor discord; do
        [[ "${DESKTOP_WANT[$k]:-}" == "1" ]] && any=1
    done
    if (( any == 0 )); then
        print_info "Nothing selected; skipping installs."
        return 1
    fi
    return 0
}

_desktop_install_chrome() {
    print_info "Installing Google Chrome..."
    case $DISTRO in
        "arch")
            yay -S --noconfirm google-chrome
            ;;
        "debian"|"fedora")
            install_package "${APP_DICT[chrome]}" "Google Chrome"
            ;;
    esac
}

_desktop_install_vscode() {
    print_info "Installing Visual Studio Code..."
    case $DISTRO in
        "arch")
            yay -S --noconfirm visual-studio-code-bin
            ;;
        *)
            install_package "${APP_DICT[vscode]}" "Visual Studio Code"
            ;;
    esac
}

_desktop_install_warp() {
    print_info "Installing Cloudflare WARP..."
    case $DISTRO in
        "fedora")
            # Docker/Podman: %post uses systemctl; PID1 is not systemd — use noscripts or install fails.
            if _desktop_in_container; then
                print_info "Container: installing WARP with tsflags=noscripts (no systemd in %post)."
                sudo dnf install -y --setopt=tsflags=noscripts cloudflare-warp
            else
                sudo dnf install -y cloudflare-warp
            fi
            ;;
        "debian")
            sudo apt install -y cloudflare-warp
            ;;
        "arch")
            yay -S --noconfirm cloudflare-warp-bin
            ;;
    esac
}

_desktop_install_cloudflared() {
    print_info "Installing cloudflared..."
    case $DISTRO in
        "fedora")
            if install_package "${APP_DICT[cloudflared]}" "cloudflared"; then
                return 0
            fi
            if rpm -q cloudflared >/dev/null 2>&1 || command -v cloudflared >/dev/null 2>&1; then
                return 0
            fi
            print_info "cloudflared not in enabled repos; installing from GitHub RPM..."
            local rpmf="/tmp/cloudflared-linux-x86_64.rpm"
            curl -fsSL --retry 3 -o "$rpmf" \
                "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-x86_64.rpm"
            sudo dnf install -y "$rpmf"
            ;;
        "arch")
            install_package "${APP_DICT[cloudflared]}" "cloudflared"
            ;;
        "debian")
            local deb="/tmp/cloudflared-linux-amd64.deb"
            curl -fsSL --retry 3 -o "$deb" \
                "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
            sudo apt install -y "$deb"
            ;;
    esac
}

_desktop_install_cursor() {
    print_info "Installing Cursor..."
    case $DISTRO in
        "fedora")
            if sudo dnf install -y cursor; then
                return 0
            fi
            if _desktop_in_container; then
                print_warning "Cursor: dnf install failed (repo/network). Skipping in container."
                return 0
            fi
            print_warning "Cursor: dnf failed; trying direct RPM (set CURSOR_RPM_URL to override)..."
            local url="${CURSOR_RPM_URL:-https://downloader.cursor.sh/linux/rpm/x64}"
            local out=/tmp/cursor-linux.rpm
            rm -f "$out"
            curl -fL --retry 3 --connect-timeout 25 -o "$out" "$url" || return 1
            [[ -s "$out" ]] || return 1
            sudo dnf install -y "$out"
            ;;
        "debian")
            if sudo apt-get install -y cursor; then
                return 0
            fi
            if _desktop_in_container; then
                print_warning "Cursor: apt install failed. Skipping in container."
                return 0
            fi
            print_warning "Cursor: apt failed; trying direct .deb (CURSOR_DEB_URL)..."
            local url="${CURSOR_DEB_URL:-https://downloader.cursor.sh/linux/deb/x64}"
            local out=/tmp/cursor-linux.deb
            rm -f "$out"
            curl -fL --retry 3 --connect-timeout 25 -o "$out" "$url" || return 1
            [[ -s "$out" ]] || return 1
            sudo apt-get install -y "$out"
            ;;
        "arch")
            yay -S --noconfirm cursor-bin
            ;;
    esac
}

_desktop_install_discord() {
    print_info "Installing Discord..."
    case $DISTRO in
        "fedora")
            setup_rpmfusion_nonfree_fedora
            sudo dnf install -y discord
            ;;
        "debian")
            curl -fL --retry 2 -o /tmp/discord-linux.deb \
                "https://discord.com/api/download?platform=linux&format=deb"
            sudo apt install -y /tmp/discord-linux.deb
            ;;
        "arch")
            install_package discord Discord
            ;;
    esac
}

_desktop_dpkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

_desktop_verify_chrome() {
    case $DISTRO in
        fedora)
            rpm -q google-chrome-stable &>/dev/null && return 0
            rpm -q google-chrome &>/dev/null && return 0
            return 1
            ;;
        debian)
            _desktop_dpkg_installed google-chrome-stable
            ;;
        arch)
            pacman -Qi google-chrome &>/dev/null
            ;;
        *) return 1 ;;
    esac
}

_desktop_verify_vscode() {
    case $DISTRO in
        fedora) rpm -q code &>/dev/null ;;
        debian) _desktop_dpkg_installed code ;;
        arch) pacman -Qi visual-studio-code-bin &>/dev/null ;;
        *) return 1 ;;
    esac
}

_desktop_verify_warp() {
    command -v warp-cli &>/dev/null && return 0
    case $DISTRO in
        fedora) rpm -q cloudflare-warp &>/dev/null ;;
        debian) _desktop_dpkg_installed cloudflare-warp ;;
        arch) pacman -Qi cloudflare-warp-bin &>/dev/null ;;
        *) return 1 ;;
    esac
}

_desktop_verify_cloudflared() {
    command -v cloudflared &>/dev/null && return 0
    case $DISTRO in
        fedora) rpm -q cloudflared &>/dev/null ;;
        debian) _desktop_dpkg_installed cloudflared ;;
        arch) pacman -Qi cloudflared &>/dev/null ;;
        *) return 1 ;;
    esac
}

_desktop_verify_cursor() {
    command -v cursor &>/dev/null && return 0
    case $DISTRO in
        fedora) rpm -q cursor &>/dev/null ;;
        debian) _desktop_dpkg_installed cursor ;;
        arch) pacman -Qi cursor-bin &>/dev/null || pacman -Qi cursor &>/dev/null ;;
        *) return 1 ;;
    esac
}

_desktop_verify_discord() {
    case $DISTRO in
        fedora) rpm -q discord &>/dev/null ;;
        debian) _desktop_dpkg_installed discord ;;
        arch) pacman -Qi discord &>/dev/null ;;
        *) return 1 ;;
    esac
}

# Run after all installs in desktop_apps_install_selected (last step before success).
desktop_apps_verify_selected_installs() {
    print_header "VERIFY SELECTED APPLICATIONS"

    local bad=0
    if [[ "${DESKTOP_WANT[chrome]:-}" == "1" ]]; then
        if _desktop_verify_chrome; then
            print_success "Verify: Google Chrome (stable channel) OK"
        else
            print_error "Verify: Google Chrome (stable) not found — expected google-chrome-stable (or Arch google-chrome)."
            bad=1
        fi
    fi
    if [[ "${DESKTOP_WANT[vscode]:-}" == "1" ]]; then
        if _desktop_verify_vscode; then
            print_success "Verify: Visual Studio Code OK"
        else
            print_error "Verify: Visual Studio Code (code) not found."
            bad=1
        fi
    fi
    if [[ "${DESKTOP_WANT[warp]:-}" == "1" ]]; then
        if _desktop_verify_warp; then
            print_success "Verify: Cloudflare WARP OK"
        else
            print_error "Verify: WARP (cloudflare-warp / warp-cli) not found."
            bad=1
        fi
    fi
    if [[ "${DESKTOP_WANT[cloudflared]:-}" == "1" ]]; then
        if _desktop_verify_cloudflared; then
            print_success "Verify: cloudflared OK"
        else
            print_error "Verify: cloudflared not found."
            bad=1
        fi
    fi
    if [[ "${DESKTOP_WANT[cursor]:-}" == "1" ]]; then
        if _desktop_verify_cursor; then
            print_success "Verify: Cursor OK"
        else
            print_error "Verify: Cursor not found."
            bad=1
        fi
    fi
    if [[ "${DESKTOP_WANT[discord]:-}" == "1" ]]; then
        if _desktop_verify_discord; then
            print_success "Verify: Discord OK"
        else
            print_error "Verify: Discord not found."
            bad=1
        fi
    fi

    if (( bad )); then
        return 1
    fi
    print_success "Post-install verification passed for all selected applications."
    return 0
}

desktop_apps_install_selected() {
    print_header "INSTALLING SELECTED APPLICATIONS"
    print_info "Adding or enabling a vendor repository only for the applications you selected."

    local fail=0
    local need_cv_repos=0
    [[ "${DESKTOP_WANT[chrome]:-}" == "1" || "${DESKTOP_WANT[vscode]:-}" == "1" ]] && need_cv_repos=1

    if [[ "$DISTRO" == "arch" ]]; then
        if [[ "${DESKTOP_WANT[chrome]:-}" == "1" || "${DESKTOP_WANT[vscode]:-}" == "1" || "${DESKTOP_WANT[warp]:-}" == "1" || "${DESKTOP_WANT[cursor]:-}" == "1" ]]; then
            setup_third_party_repos || fail=1
        fi
    elif (( need_cv_repos )); then
        setup_third_party_repos || fail=1
    fi
    if [[ "${DESKTOP_WANT[warp]:-}" == "1" ]]; then
        setup_cloudflare_warp_repo || fail=1
    fi
    if [[ "${DESKTOP_WANT[cursor]:-}" == "1" ]]; then
        setup_cursor_repo || fail=1
    fi
    if [[ "$DISTRO" == "fedora" ]] && [[ "${DESKTOP_WANT[discord]:-}" == "1" ]]; then
        setup_rpmfusion_nonfree_fedora || fail=1
    fi
    if (( fail )); then
        print_error "Repository setup failed."
        return 1
    fi

    [[ "${DESKTOP_WANT[chrome]:-}" == "1" ]] && { _desktop_install_chrome || fail=1; }
    [[ "${DESKTOP_WANT[vscode]:-}" == "1" ]] && { _desktop_install_vscode || fail=1; }
    [[ "${DESKTOP_WANT[warp]:-}" == "1" ]] && { _desktop_install_warp || fail=1; }
    [[ "${DESKTOP_WANT[cloudflared]:-}" == "1" ]] && { _desktop_install_cloudflared || fail=1; }
    [[ "${DESKTOP_WANT[cursor]:-}" == "1" ]] && { _desktop_install_cursor || fail=1; }
    [[ "${DESKTOP_WANT[discord]:-}" == "1" ]] && { _desktop_install_discord || fail=1; }

    if (( fail )); then
        print_error "One or more application installs failed."
        return 1
    fi
    if ! desktop_apps_verify_selected_installs; then
        print_error "Post-install verification failed (selected apps not all present)."
        return 1
    fi
    print_success "Selected application installs finished."
}

desktop_apps_pick_and_install() {
    desktop_apps_prompt_selection
    local ec=$?
    if (( ec == TUI_BACK_TO_MAIN )); then
        return "$ec"
    fi
    (( ec != 0 )) && return 0
    desktop_apps_install_selected
}
