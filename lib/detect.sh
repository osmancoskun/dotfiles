# Distribution detection and application dictionary initialization.
# Expects: print_*, DISTRO, PACKAGE_MANAGER, INSTALL_CMD, UPDATE_CMD, APP_DICT (associative array).

# Initialize application dictionary based on distro
init_app_dict() {
    case $DISTRO in
        "arch")
            APP_DICT=(
                ["git"]="git"
                ["curl"]="curl"
                ["wget"]="wget"
                ["zsh"]="zsh"
                ["stow"]="stow"
                ["nodejs"]="nodejs npm"
                ["yarn"]="yarn"
                ["chrome"]="google-chrome"
                ["vscode"]="code"
                ["cloudflared"]="cloudflared"
                ["discord"]="discord"
                ["pnpm"]="pnpm"
            )
            ;;
        "debian"|"ubuntu")
            APP_DICT=(
                ["git"]="git"
                ["curl"]="curl"
                ["wget"]="wget"
                ["zsh"]="zsh"
                ["stow"]="stow"
                ["nodejs"]="nodejs npm"
                ["yarn"]="yarnpkg"
                ["chrome"]="google-chrome-stable"
                ["vscode"]="code"
                ["pnpm"]="pnpm"
            )
            ;;
        "fedora")
            APP_DICT=(
                ["git"]="git"
                ["curl"]="curl"
                ["wget"]="wget"
                ["zsh"]="zsh"
                ["stow"]="stow"
                ["nodejs"]="nodejs nodejs-npm"
                ["yarn"]="yarn"
                ["chrome"]="google-chrome-stable"
                ["vscode"]="code"
                ["cloudflared"]="cloudflared"
                ["pnpm"]="pnpm"
            )
            ;;
    esac
}

# Detect distribution
detect_distro() {
    print_info "Detecting Linux distribution..."

    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        case "$ID" in
            "arch"|"manjaro")
                DISTRO="arch"
                PACKAGE_MANAGER="pacman"
                INSTALL_CMD="sudo pacman -S --noconfirm"
                UPDATE_CMD="sudo pacman -Syu --noconfirm"
                ;;
            "ubuntu"|"debian"|"linuxmint")
                DISTRO="debian"
                PACKAGE_MANAGER="apt"
                INSTALL_CMD="sudo apt install -y"
                UPDATE_CMD="sudo apt update && sudo apt upgrade -y"
                ;;
            "fedora"|"rhel"|"centos")
                DISTRO="fedora"
                PACKAGE_MANAGER="dnf"
                INSTALL_CMD="sudo dnf install -y"
                UPDATE_CMD="sudo dnf update -y"
                ;;
            *)
                print_error "Unsupported distribution: $ID"
                exit 1
                ;;
        esac
    else
        print_error "Cannot detect distribution"
        exit 1
    fi

    print_success "Detected: $PRETTY_NAME ($DISTRO)"
    print_info "Package manager: $PACKAGE_MANAGER"
}
