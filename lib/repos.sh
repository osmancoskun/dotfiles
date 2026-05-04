# Third-party package repositories (Chrome, VSCode, yay on Arch).
# Expects: DISTRO, print_*.

# Setup third-party repositories
setup_third_party_repos() {
    print_header "SETTING UP THIRD-PARTY REPOSITORIES"

    case $DISTRO in
        "arch")
            print_info "Installing AUR helper (yay)..."
            if ! command -v yay >/dev/null 2>&1; then
                cd /tmp
                git clone https://aur.archlinux.org/yay.git
                cd yay
                makepkg -si --noconfirm
                cd ..
                rm -rf yay
                print_success "Yay AUR helper installed"
            else
                print_warning "Yay already installed"
            fi
            ;;
        "debian")
            print_info "Adding Google Chrome repository..."
            if [[ ! -f /etc/apt/sources.list.d/google-chrome.list ]]; then
                wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
                echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
                sudo apt update
            fi

            print_info "Adding VSCode repository..."
            if [[ ! -f /etc/apt/sources.list.d/vscode.list ]]; then
                wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
                sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
                echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
                sudo apt update
            fi
            ;;
        "fedora")
            print_info "Adding Google Chrome repository..."
            if [[ ! -f /etc/yum.repos.d/google-chrome.repo ]]; then
                sudo tee /etc/yum.repos.d/google-chrome.repo <<EOF
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
            fi

            print_info "Adding VSCode repository..."
            if [[ ! -f /etc/yum.repos.d/vscode.repo ]]; then
                # Re-run safe: duplicate import is an error without || true
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc || true
                sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
                # dnf check-update exits 100 when updates exist — not a failure; refresh metadata instead.
                sudo dnf makecache -y || true
            fi
            ;;
    esac
}

# Cloudflare WARP client repo (warp-cli). Matches Cloudflare Linux / RHEL docs. Idempotent.
setup_cloudflare_warp_repo() {
    case $DISTRO in
        "fedora")
            # https://pkg.cloudflareclient.com/ — rotate key if installed before 2025-09-12
            print_info "Cloudflare WARP: GPG key refresh (rpm -e old pubkey + rpm --import)..."
            sudo rpm -e 'gpg-pubkey(4fa1c3ba-61abda35)' 2>/dev/null || true
            if ! sudo rpm --import https://pkg.cloudflareclient.com/pubkey.gpg; then
                print_error "Could not import Cloudflare WARP GPG key."
                return 1
            fi
            if [[ ! -f /etc/yum.repos.d/cloudflare-warp.repo ]]; then
                print_info "Adding cloudflare-warp-ascii.repo → /etc/yum.repos.d/cloudflare-warp.repo"
                curl -fsSL -o /tmp/cloudflare-warp.repo \
                    "https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo"
                sudo install -m 644 /tmp/cloudflare-warp.repo /etc/yum.repos.d/cloudflare-warp.repo
            fi
            print_info "WARP: refreshing DNF metadata (like yum update for repo cache)..."
            sudo dnf makecache -y || true
            ;;
        "debian")
            if [[ ! -f /etc/apt/sources.list.d/cloudflare-client.list ]]; then
                print_info "Adding Cloudflare WARP APT repository..."
                # shellcheck source=/dev/null
                . /etc/os-release
                local codename="${VERSION_CODENAME:-bookworm}"
                sudo mkdir -p /usr/share/keyrings
                curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --dearmor \
                    -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
                echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${codename} main" \
                    | sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null
                sudo apt update
            fi
            ;;
        "arch")
            # AUR / extra: no separate repo file
            ;;
    esac
}

# Cursor official yum/apt (downloads.cursor.com). Same idea as apt sources.list. Idempotent.
setup_cursor_repo() {
    case $DISTRO in
        "fedora")
            if [[ ! -f /etc/yum.repos.d/cursor.repo ]]; then
                print_info "Adding Cursor yum repo (cursor.com / RHEL+Fedora instructions)..."
                sudo tee /etc/yum.repos.d/cursor.repo >/dev/null <<'EOF'
[cursor]
name=Cursor
baseurl=https://downloads.cursor.com/yumrepo
enabled=1
gpgcheck=1
gpgkey=https://downloads.cursor.com/keys/anysphere.asc
EOF
            fi
            print_info "Cursor: refreshing DNF metadata..."
            sudo dnf makecache -y || true
            ;;
        "debian")
            if [[ ! -f /etc/apt/sources.list.d/cursor.list ]]; then
                print_info "Adding Cursor APT repo (cursor.com — aptrepo)..."
                sudo mkdir -p /etc/apt/keyrings
                curl -fsSL -o /tmp/cursor-anysphere.asc https://downloads.cursor.com/keys/anysphere.asc
                sudo gpg --dearmor -o /etc/apt/keyrings/cursor.gpg /tmp/cursor-anysphere.asc
                echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/cursor.gpg] https://downloads.cursor.com/aptrepo stable main" \
                    | sudo tee /etc/apt/sources.list.d/cursor.list >/dev/null
            fi
            sudo apt-get update -y || true
            ;;
        *)
            return 0
            ;;
    esac
    return 0
}

# RPM Fusion nonfree (Discord RPM on Fedora). Idempotent.
setup_rpmfusion_nonfree_fedora() {
    [[ "$DISTRO" == "fedora" ]] || return 0
    local ver
    ver="$(rpm -E %fedora 2>/dev/null || echo 0)"
    [[ "$ver" != "0" ]] || return 0
    if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
        print_info "Enabling RPM Fusion nonfree (Discord)..."
        # dnf may return non-zero with "skipped OpenPGP checks" even when the RPM is installed.
        sudo dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${ver}.noarch.rpm" || true
    fi
    if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
        print_error "RPM Fusion nonfree release is not installed."
        return 1
    fi
    return 0
}
