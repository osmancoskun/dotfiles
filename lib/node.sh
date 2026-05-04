# Node.js, Yarn, pnpm.
# Expects: DISTRO, APP_DICT, print_*, install_package (from lib/packages.sh).

# Install Node.js and package managers
install_nodejs_tools() {
    print_header "INSTALLING NODE.JS AND PACKAGE MANAGERS"

    # Install Node.js and npm
    if [[ -n "${APP_DICT[nodejs]:-}" ]]; then
        install_package "${APP_DICT[nodejs]}" "Node.js and npm"
    fi

    # Install Yarn
    print_info "Installing Yarn..."
    if ! command -v yarn >/dev/null 2>&1; then
        case $DISTRO in
            "arch")
                yay -S --noconfirm yarn
                ;;
            "debian")
                curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
                echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
                sudo apt update && sudo apt install -y yarn
                ;;
            "fedora")
                curl -sL https://dl.yarnpkg.com/rpm/yarn.repo | sudo tee /etc/yum.repos.d/yarn.repo
                sudo dnf install -y yarn
                ;;
        esac
        print_success "Yarn installed"
    else
        print_warning "Yarn already installed"
    fi

    # Install pnpm from distro repos only (Fedora: dnf install pnpm — no npm -g)
    if [[ -n "${APP_DICT[pnpm]:-}" ]]; then
        install_package "${APP_DICT[pnpm]}" "pnpm"
    fi
}
