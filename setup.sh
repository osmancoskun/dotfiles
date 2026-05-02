#!/bin/bash

# Multi-Distribution Auto Setup Script
# Supports: Arch Linux, Debian/Ubuntu, Fedora
# Author: Generated for osmancoskun
# Version: 1.0

set -euo pipefail  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
DISTRO=""
PACKAGE_MANAGER=""
INSTALL_CMD=""
UPDATE_CMD=""
DOTFILES_DIR="$HOME/.dotfiles"
LOG_FILE="$HOME/setup.log"

# Application dictionary - maps generic names to distro-specific package names
declare -A APP_DICT

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
                ["chrome"]="google-chrome"
                ["vscode"]="code"
                ["pnpm"]="pnpm"
            )
            ;;
    esac
}

# Logging function
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Print colored info messages
print_info() {
    log "${BLUE}[INFO]${NC} $1"
}

print_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    log "${RED}[ERROR]${NC} $1"
}

print_header() {
    log "${MAGENTA}========================================${NC}"
    log "${MAGENTA} $1${NC}"
    log "${MAGENTA}========================================${NC}"
}

# Error handler
error_handler() {
    print_error "Script failed at line $1. Exiting..."
    print_info "Check log file: $LOG_FILE"
    exit 1
}

trap 'error_handler $LINENO' ERR

# Detect distribution
detect_distro() {
    print_info "Detecting Linux distribution..."
    
    if [[ -f /etc/os-release ]]; then
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
                sudo pacman -S --noconfirm "${need[@]}"
                print_success "$display_name installed"
            else
                print_warning "$display_name already installed"
            fi
            ;;
        "debian")
            local -a need=()
            for p in "${pkgs[@]}"; do
                if ! dpkg -l 2>/dev/null | grep -q "^ii  $p "; then
                    need+=("$p")
                fi
            done
            if ((${#need[@]})); then
                sudo apt install -y "${need[@]}"
                print_success "$display_name installed"
            else
                print_warning "$display_name already installed"
            fi
            ;;
        "fedora")
            local -a need=()
            for p in "${pkgs[@]}"; do
                if ! rpm -q "$p" >/dev/null 2>&1; then
                    need+=("$p")
                fi
            done
            if ((${#need[@]})); then
                sudo dnf install -y "${need[@]}"
                print_success "$display_name installed"
            else
                print_warning "$display_name already installed"
            fi
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
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
                sudo dnf check-update
            fi
            ;;
    esac
}

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

# Install applications
install_applications() {
    print_header "INSTALLING APPLICATIONS"
    
    # Google Chrome
    print_info "Installing Google Chrome..."
    case $DISTRO in
        "arch")
            yay -S --noconfirm google-chrome
            ;;
        "debian"|"fedora")
            install_package "${APP_DICT[chrome]}" "Google Chrome"
            ;;
    esac
    
    # VSCode
    install_package "${APP_DICT[vscode]}" "Visual Studio Code"
}

# Install and setup Oh My Zsh
setup_oh_my_zsh() {
    print_header "SETTING UP OH MY ZSH"
    
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        print_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        print_success "Oh My Zsh installed"
    else
        print_warning "Oh My Zsh already installed"
    fi
    
    # Install popular plugins
    print_info "Installing Oh My Zsh plugins..."
    
    local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    
    # zsh-autosuggestions
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        print_success "zsh-autosuggestions installed"
    fi
    
    # zsh-syntax-highlighting
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
        print_success "zsh-syntax-highlighting installed"
    fi
    
    # zsh-history-substring-search
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-history-substring-search" ]]; then
        git clone https://github.com/zsh-users/zsh-history-substring-search "$ZSH_CUSTOM/plugins/zsh-history-substring-search"
        print_success "zsh-history-substring-search installed"
    fi
    
    # Ensure ~/.zshrc exists (e.g. if a previous setup step moved it away)
    if [[ ! -f "$HOME/.zshrc" ]] && [[ -f "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" ]]; then
        print_info "Creating ~/.zshrc from Oh My Zsh template..."
        cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
        print_success "~/.zshrc created"
    fi
}

# Setup dotfiles
setup_dotfiles() {
    print_header "SETTING UP DOTFILES"
    
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        print_info "Cloning dotfiles repository..."
        git clone https://github.com/osmancoskun/dotfiles.git "$DOTFILES_DIR"
        print_success "Dotfiles cloned"
    else
        print_info "Updating dotfiles repository..."
        cd "$DOTFILES_DIR"
        git pull
        print_success "Dotfiles updated"
    fi
    
    print_info "Stowing GNU Stow package 'home' into \$HOME..."
    cd "$DOTFILES_DIR" || return
    
    if ! command -v stow >/dev/null 2>&1; then
        print_warning "Stow not installed; install stow and re-run this step."
        return
    fi
    if [[ ! -d "$DOTFILES_DIR/home" ]]; then
        print_error "Missing stow package directory: $DOTFILES_DIR/home"
        return
    fi
    
    # home/ mirrors $HOME: .config/, .vimrc, Wallpapers/, etc.
    # stow merges into existing ~/.config (other apps keep their trees).
    stow --restow --target="$HOME" home
    print_success "Dotfiles stowed (home → \$HOME). Conflicts: stow -n --adopt home (see stow(8))."
}

# Change default shell to zsh
change_shell() {
    print_header "CHANGING DEFAULT SHELL"
    
    if [[ "$SHELL" != "$(which zsh)" ]]; then
        print_info "Changing default shell to zsh..."
        chsh -s "$(which zsh)"
        print_success "Default shell changed to zsh (restart terminal to apply)"
    else
        print_warning "Default shell is already zsh"
    fi
}

# Main execution
main() {
    print_header "MULTI-DISTRO AUTO SETUP SCRIPT"
    print_info "Starting setup process..."
    print_info "Log file: $LOG_FILE"
    
    # Initialize log
    echo "Setup started at $(date)" > "$LOG_FILE"
    
    # Detect distribution and initialize
    detect_distro
    init_app_dict
    
    # Confirmation
    print_info "This script will install and configure the following:"
    print_info "- Core packages (git, curl, wget, zsh, stow)"
    print_info "- Node.js, npm, yarn, pnpm"
    print_info "- Google Chrome, VSCode"
    print_info "- Oh My Zsh with plugins"
    print_info "- Dotfiles from github.com/osmancoskun/dotfiles"
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Setup cancelled by user"
        exit 0
    fi
    
    # Execute setup steps
    update_system
    setup_third_party_repos
    install_core_packages
    install_nodejs_tools
    install_applications
    setup_oh_my_zsh
    setup_dotfiles
    change_shell
    
    print_header "SETUP COMPLETED"
    print_success "All packages and configurations have been installed!"
    print_info "Open a new terminal or run:  zsh -l   then optionally   source ~/.zshrc"
    print_info "Setup log saved to: $LOG_FILE"
    
    echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
}

# Run main function
main "$@"
