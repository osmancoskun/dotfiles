# Desktop applications (Chrome, VSCode).
# Expects: DISTRO, APP_DICT, print_*, install_package (from lib/packages.sh).

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
