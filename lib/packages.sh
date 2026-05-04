# System update, generic install, and core package bundle.
# Expects: DISTRO, APP_DICT, print_*, install_package (this file).

# Update system
update_system() {
    print_header "UPDATING SYSTEM"
    print_info "Running system update..."

    case $DISTRO in
        "arch")
            sudo pacman -Syu --noconfirm
            ;;
        "debian")
            sudo apt update && sudo apt upgrade -y
            ;;
        "fedora")
            sudo dnf update -y
            ;;
    esac

    print_success "System updated successfully"
}

# Install package (package_name may be space-separated, e.g. "nodejs nodejs-npm" on Fedora)
install_package() {
    local package_name="$1"
    local display_name="$2"
    local -a pkgs=()
    read -ra pkgs <<< "$package_name"

    print_info "Installing $display_name..."

    case $DISTRO in
        "arch")
            local -a need=()
            for p in "${pkgs[@]}"; do
                if ! pacman -Qi "$p" >/dev/null 2>&1; then
                    need+=("$p")
                fi
            done
            if ((${#need[@]})); then
                if ! sudo pacman -S --noconfirm "${need[@]}"; then
                    print_error "Failed to install $display_name"
                    return 1
                fi
                print_success "$display_name installed"
            else
                print_warning "$display_name already installed"
            fi
            return 0
            ;;
        "debian")
            local -a need=()
            for p in "${pkgs[@]}"; do
                if ! dpkg -l 2>/dev/null | grep -q "^ii  $p "; then
                    need+=("$p")
                fi
            done
            if ((${#need[@]})); then
                if ! sudo apt install -y "${need[@]}"; then
                    print_error "Failed to install $display_name"
                    return 1
                fi
                print_success "$display_name installed"
            else
                print_warning "$display_name already installed"
            fi
            return 0
            ;;
        "fedora")
            local -a need=()
            for p in "${pkgs[@]}"; do
                if ! rpm -q "$p" >/dev/null 2>&1; then
                    need+=("$p")
                fi
            done
            if ((${#need[@]})); then
                if ! sudo dnf install -y "${need[@]}"; then
                    print_error "Failed to install $display_name"
                    return 1
                fi
                print_success "$display_name installed"
            else
                print_warning "$display_name already installed"
            fi
            return 0
            ;;
    esac
}

# Install core packages
install_core_packages() {
    print_header "INSTALLING CORE PACKAGES"

    local core_packages=("git" "curl" "wget" "zsh" "stow")

    for package in "${core_packages[@]}"; do
        if [[ -n "${APP_DICT[$package]:-}" ]]; then
            install_package "${APP_DICT[$package]}" "$package"
        fi
    done
}
