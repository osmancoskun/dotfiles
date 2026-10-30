# Optional packages from the distribution repositories only (no Google/MS/Cursor repos here).
# Expects: DISTRO, APP_DICT, print_*, install_package, numbered_prompt_apply_line_to_want (numbered-prompt.sh),
#          tui_read_with_back, TUI_BACK_TO_MAIN (tui-back.sh; setup.sh sources it before this file).

declare -gA REPO_WANT=()
declare -gA REPO_PKGMAP=()
declare -ga REPO_ORDER=()
declare -ga REPO_LABELS=()

# Populate REPO_ORDER and REPO_PKGMAP. Call after init_app_dict.
init_repo_package_map() {
    REPO_ORDER=(git openssh ssh-askpass nc nettools jq htop ripgrep fd bat zip tree build dnsutils python nodejs yarn pnpm cascadia-code noto-sans-mono virt-manager wlsunset)
    REPO_PKGMAP=()
    REPO_LABELS=()
    case $DISTRO in
        fedora)
            REPO_PKGMAP[git]=git
            REPO_PKGMAP[openssh]=openssh-clients
            REPO_PKGMAP[ssh-askpass]=openssh-askpass
            REPO_PKGMAP[nc]=nmap-ncat
            REPO_PKGMAP[nettools]="net-tools iproute"
            REPO_PKGMAP[jq]=jq
            REPO_PKGMAP[htop]=htop
            REPO_PKGMAP[ripgrep]=ripgrep
            REPO_PKGMAP[fd]=fd-find
            REPO_PKGMAP[bat]=bat
            REPO_PKGMAP[zip]="unzip zip"
            REPO_PKGMAP[tree]=tree
            REPO_PKGMAP[build]="gcc gcc-c++ make"
            REPO_PKGMAP[dnsutils]=bind-utils
            REPO_PKGMAP[python]="python3 python3-pip"
            REPO_PKGMAP[nodejs]="${APP_DICT[nodejs]}"
            REPO_PKGMAP[yarn]="${APP_DICT[yarn]}"
            REPO_PKGMAP[pnpm]="${APP_DICT[pnpm]}"
            REPO_PKGMAP[cascadia-code]=cascadia-code-fonts
            REPO_PKGMAP[noto-sans-mono]=google-noto-sans-mono-vf-fonts
            REPO_PKGMAP[virt-manager]="virt-manager virt-install virt-viewer qemu-kvm qemu-img libvirt-daemon-kvm libvirt-daemon-config-network dnsmasq edk2-ovmf"
            REPO_PKGMAP[wlsunset]=wlsunset
            ;;
        debian)
            REPO_PKGMAP[git]=git
            REPO_PKGMAP[openssh]=openssh-client
            REPO_PKGMAP[ssh-askpass]=ssh-askpass-gnome
            REPO_PKGMAP[nc]=netcat-openbsd
            REPO_PKGMAP[nettools]="net-tools iproute2"
            REPO_PKGMAP[jq]=jq
            REPO_PKGMAP[htop]=htop
            REPO_PKGMAP[ripgrep]=ripgrep
            REPO_PKGMAP[fd]=fd-find
            REPO_PKGMAP[bat]=bat
            REPO_PKGMAP[zip]="unzip zip"
            REPO_PKGMAP[tree]=tree
            REPO_PKGMAP[build]=build-essential
            REPO_PKGMAP[dnsutils]=dnsutils
            REPO_PKGMAP[python]="python3 python3-pip"
            REPO_PKGMAP[nodejs]="${APP_DICT[nodejs]}"
            REPO_PKGMAP[yarn]="${APP_DICT[yarn]}"
            REPO_PKGMAP[pnpm]="${APP_DICT[pnpm]}"
            REPO_PKGMAP[cascadia-code]=fonts-cascadia-code
            REPO_PKGMAP[noto-sans-mono]=fonts-noto-mono
            REPO_PKGMAP[virt-manager]="virt-manager virtinst virt-viewer qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients dnsmasq-base ovmf"
            REPO_PKGMAP[wlsunset]=wlsunset
            ;;
        arch)
            REPO_PKGMAP[git]=git
            REPO_PKGMAP[openssh]=openssh
            REPO_PKGMAP[ssh-askpass]=x11-ssh-askpass
            REPO_PKGMAP[nc]=openbsd-netcat
            REPO_PKGMAP[nettools]="net-tools iproute2"
            REPO_PKGMAP[jq]=jq
            REPO_PKGMAP[htop]=htop
            REPO_PKGMAP[ripgrep]=ripgrep
            REPO_PKGMAP[fd]=fd
            REPO_PKGMAP[bat]=bat
            REPO_PKGMAP[zip]="unzip zip"
            REPO_PKGMAP[tree]=tree
            REPO_PKGMAP[build]="gcc make"
            REPO_PKGMAP[dnsutils]=bind-tools
            REPO_PKGMAP[python]="python python-pip"
            REPO_PKGMAP[nodejs]="${APP_DICT[nodejs]}"
            REPO_PKGMAP[yarn]="${APP_DICT[yarn]}"
            REPO_PKGMAP[pnpm]="${APP_DICT[pnpm]}"
            REPO_PKGMAP[cascadia-code]=ttf-cascadia-code
            REPO_PKGMAP[noto-sans-mono]=noto-fonts
            REPO_PKGMAP[virt-manager]="virt-manager virt-install virt-viewer qemu-desktop qemu-img libvirt dnsmasq edk2-ovmf"
            REPO_PKGMAP[wlsunset]=wlsunset
            ;;
        *)
            return 1
            ;;
    esac
    REPO_LABELS=(
        "Git"
        "OpenSSH client (ssh, scp)"
        "ssh-askpass (SSH key passphrase dialog)"
        "netcat (nc)"
        "Networking CLI (net-tools, iproute)"
        "jq"
        "htop"
        "ripgrep (rg)"
        "fd"
        "bat"
        "zip / unzip"
        "tree"
        "C build tools (gcc, make)"
        "DNS tools (dig, nslookup)"
        "Python 3 + pip"
        "Node.js + npm (distro packages)"
        "Yarn (distro package)"
        "pnpm (distro package)"
        "Cascadia Code (terminal / coding font)"
        "Noto Sans Mono (terminal fallback font)"
        "virt-manager (QEMU/KVM + libvirt)"
        "wlsunset (blue light filter)"
    )
    if ((${#REPO_ORDER[@]} != ${#REPO_LABELS[@]})); then
        print_error "repo-packages: REPO_ORDER / REPO_LABELS length mismatch (internal bug)."
        return 1
    fi
}

# Comma-separated keys; same ids as REPO_ORDER. Unknown keys ignored with warning.
repo_packages_set_want_from_csv() {
    local csv=${1:-}
    REPO_WANT=()
    [[ -z "$csv" ]] && return 1
    init_repo_package_map || return 1
    local _p
    IFS=',' read -ra _parts <<< "$csv"
    for _p in "${_parts[@]}"; do
        _p="${_p//[$'\t\r\n ']/}"
        [[ -z "$_p" ]] && continue
        if [[ -n "${REPO_PKGMAP[$_p]:-}" ]]; then
            REPO_WANT["$_p"]=1
        else
            print_warning "Unknown repo package key '$_p' (ignored)."
        fi
    done
    local any=0
    for k in "${REPO_ORDER[@]}"; do
        [[ "${REPO_WANT[$k]:-}" == "1" ]] && any=1
    done
    (( any )) || return 1
    return 0
}

repo_packages_prompt_selection() {
    REPO_WANT=()
    init_repo_package_map || {
        print_error "repo-packages: unsupported DISTRO."
        return 1
    }
    print_header "SELECT REPOSITORY PACKAGES"
    print_info "Only packages from your distro mirrors / default repos (no third-party vendor repos)."

    local max=${#REPO_ORDER[@]}
    local i
    print_info ""
    for ((i = 0; i < max; i++)); do
        print_info "  $((i + 1))) ${REPO_LABELS[i]}"
    done
    print_info "  0) All listed above"
    print_info ""
    print_info "Type the numbers you want (spaces or commas), then Enter — e.g. 1 3 6"
    print_info "B) Back to main menu"
    local line=
    tui_read_with_back "> " line || return $?

    numbered_prompt_apply_line_to_want "$line" "$max" REPO_WANT "${REPO_ORDER[@]}"

    local any=0
    for k in "${REPO_ORDER[@]}"; do
        [[ "${REPO_WANT[$k]:-}" == "1" ]] && any=1
    done
    if (( any == 0 )); then
        print_info "Nothing selected; skipping repository package installs."
        return 1
    fi
    return 0
}

_repo_verify_nc() {
    command -v nc &>/dev/null || command -v ncat &>/dev/null || command -v netcat &>/dev/null
}

_repo_verify_fd() {
    command -v fd &>/dev/null || command -v fdfind &>/dev/null
}

_repo_verify_nettools() {
    command -v ip &>/dev/null || command -v ifconfig &>/dev/null
}

_repo_verify_ssh_askpass() {
    command -v ssh-askpass &>/dev/null \
        || [[ -x /usr/libexec/openssh/ssh-askpass ]] \
        || [[ -x /usr/libexec/openssh/gnome-ssh-askpass ]] \
        || [[ -x /usr/lib/ssh/x11-ssh-askpass ]]
}

_repo_verify_cascadia_code() {
    fc-match -f '%{family}' 'Cascadia Code' 2>/dev/null | grep -qi cascadia
}

_repo_verify_noto_sans_mono() {
    fc-match -f '%{family}' 'Noto Sans Mono' 2>/dev/null | grep -qi 'noto sans mono'
}

repo_packages_verify_selected() {
    print_header "VERIFY REPOSITORY PACKAGES"
    local bad=0

    if [[ "${REPO_WANT[git]:-}" == "1" ]]; then
        if command -v git &>/dev/null; then
            print_success "Verify: git OK"
        else
            print_error "Verify: git missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[openssh]:-}" == "1" ]]; then
        if command -v ssh &>/dev/null; then
            print_success "Verify: OpenSSH client OK"
        else
            print_error "Verify: ssh missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[ssh-askpass]:-}" == "1" ]]; then
        if _repo_verify_ssh_askpass; then
            print_success "Verify: ssh-askpass OK"
        else
            print_error "Verify: ssh-askpass missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[nc]:-}" == "1" ]]; then
        if _repo_verify_nc; then
            print_success "Verify: netcat OK"
        else
            print_error "Verify: nc/ncat not found."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[nettools]:-}" == "1" ]]; then
        if _repo_verify_nettools; then
            print_success "Verify: networking CLI OK"
        else
            print_error "Verify: ip/ifconfig missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[jq]:-}" == "1" ]]; then
        if command -v jq &>/dev/null; then
            print_success "Verify: jq OK"
        else
            print_error "Verify: jq missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[htop]:-}" == "1" ]]; then
        if command -v htop &>/dev/null; then
            print_success "Verify: htop OK"
        else
            print_error "Verify: htop missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[ripgrep]:-}" == "1" ]]; then
        if command -v rg &>/dev/null; then
            print_success "Verify: ripgrep OK"
        else
            print_error "Verify: rg missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[fd]:-}" == "1" ]]; then
        if _repo_verify_fd; then
            print_success "Verify: fd OK"
        else
            print_error "Verify: fd/fdfind missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[bat]:-}" == "1" ]]; then
        if command -v bat &>/dev/null || command -v batcat &>/dev/null; then
            print_success "Verify: bat OK"
        else
            print_error "Verify: bat/batcat missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[zip]:-}" == "1" ]]; then
        if command -v zip &>/dev/null && command -v unzip &>/dev/null; then
            print_success "Verify: zip/unzip OK"
        else
            print_error "Verify: zip or unzip missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[tree]:-}" == "1" ]]; then
        if command -v tree &>/dev/null; then
            print_success "Verify: tree OK"
        else
            print_error "Verify: tree missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[build]:-}" == "1" ]]; then
        if command -v gcc &>/dev/null && command -v make &>/dev/null; then
            print_success "Verify: build tools OK"
        else
            print_error "Verify: gcc or make missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[dnsutils]:-}" == "1" ]]; then
        if command -v dig &>/dev/null || command -v nslookup &>/dev/null; then
            print_success "Verify: DNS utils OK"
        else
            print_error "Verify: dig/nslookup missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[python]:-}" == "1" ]]; then
        if command -v python3 &>/dev/null; then
            print_success "Verify: Python 3 OK"
        else
            print_error "Verify: python3 missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[nodejs]:-}" == "1" ]]; then
        if command -v node &>/dev/null; then
            print_success "Verify: Node.js OK"
        else
            print_error "Verify: node missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[yarn]:-}" == "1" ]]; then
        if command -v yarn &>/dev/null; then
            print_success "Verify: Yarn OK"
        else
            print_error "Verify: yarn missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[pnpm]:-}" == "1" ]]; then
        if command -v pnpm &>/dev/null; then
            print_success "Verify: pnpm OK"
        else
            print_error "Verify: pnpm missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[cascadia-code]:-}" == "1" ]]; then
        if _repo_verify_cascadia_code; then
            print_success "Verify: Cascadia Code font OK"
        else
            print_error "Verify: Cascadia Code font missing (install ${REPO_PKGMAP[cascadia-code]:-cascadia-code})."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[noto-sans-mono]:-}" == "1" ]]; then
        if _repo_verify_noto_sans_mono; then
            print_success "Verify: Noto Sans Mono font OK"
        else
            print_error "Verify: Noto Sans Mono font missing (install ${REPO_PKGMAP[noto-sans-mono]:-noto-sans-mono})."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[virt-manager]:-}" == "1" ]]; then
        if command -v virt-manager &>/dev/null && command -v virsh &>/dev/null; then
            print_success "Verify: virt-manager / virsh OK"
        else
            print_error "Verify: virt-manager or virsh missing."
            bad=1
        fi
    fi
    if [[ "${REPO_WANT[wlsunset]:-}" == "1" ]]; then
        if command -v wlsunset &>/dev/null; then
            print_success "Verify: wlsunset OK"
        else
            print_error "Verify: wlsunset missing."
            bad=1
        fi
    fi

    if (( bad )); then
        return 1
    fi
    print_success "Post-install verification passed for selected repository packages."
    return 0
}

_repo_in_container() {
    [[ -f /run/.containerenv || -f /.dockerenv ]]
}

_repo_has_systemd() {
    [[ -d /run/systemd/system ]] && command -v systemctl &>/dev/null && ! _repo_in_container
}

_repo_target_user() {
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != root ]]; then
        printf '%s\n' "$SUDO_USER"
    else
        printf '%s\n' "${USER:-$(id -un)}"
    fi
}

_repo_ensure_group_member() {
    local user=$1 group=$2
    if [[ "$user" == root ]]; then
        print_warning "Skip group '$group' (target user is root)."
        return 0
    fi
    if ! getent group "$group" >/dev/null; then
        print_error "Group '$group' does not exist."
        return 1
    fi
    if id -nG "$user" 2>/dev/null | grep -qw "$group"; then
        print_warning "$user already in group $group"
        return 0
    fi
    if ! sudo usermod -aG "$group" "$user"; then
        print_error "Failed to add $user to group $group."
        return 1
    fi
    print_success "Added $user to group $group (log out and back in)"
}

_repo_enable_now() {
    local unit=$1
    if ! _repo_has_systemd; then
        print_warning "No systemd session; skip $unit."
        return 0
    fi
    if ! systemctl cat "$unit" &>/dev/null; then
        print_warning "Unit $unit not found; skip."
        return 0
    fi
    if systemctl is-enabled --quiet "$unit" && systemctl is-active --quiet "$unit"; then
        print_warning "$unit already enabled and running"
        return 0
    fi
    if ! sudo systemctl enable --now "$unit"; then
        print_error "Failed to enable --now $unit."
        return 1
    fi
    print_success "Enabled and started $unit"
}

_repo_configure_virt_manager() {
    print_header "CONFIGURE VIRT-MANAGER"
    local user fail=0
    user="$(_repo_target_user)"
    _repo_ensure_group_member "$user" libvirt || fail=1
    if getent group kvm >/dev/null; then
        _repo_ensure_group_member "$user" kvm || fail=1
    fi

    local any=0 u
    case $DISTRO in
        fedora)
            for u in virtqemud.service virtnetworkd.service virtstoraged.service; do
                if systemctl cat "$u" &>/dev/null; then
                    _repo_enable_now "$u" || fail=1
                    any=1
                fi
            done
            if (( any == 0 )); then
                _repo_enable_now libvirtd.service || fail=1
            fi
            ;;
        *)
            _repo_enable_now libvirtd.service || fail=1
            ;;
    esac

    if command -v virsh &>/dev/null && _repo_has_systemd; then
        if sudo virsh net-info default &>/dev/null; then
            sudo virsh net-autostart default || fail=1
            local active
            active=$(sudo virsh net-info default 2>/dev/null | awk '/^Active:/{print $2}')
            if [[ "$active" != yes ]]; then
                sudo virsh net-start default || fail=1
            fi
            print_success "libvirt default network set to autostart"
        else
            print_warning "libvirt default network not defined; skip autostart."
        fi
    fi

    return "$fail"
}

repo_packages_configure_selected() {
    local fail=0
    if [[ "${REPO_WANT[virt-manager]:-}" == "1" ]]; then
        _repo_configure_virt_manager || fail=1
    fi
    return "$fail"
}

repo_packages_install_selected() {
    print_header "INSTALLING SELECTED REPOSITORY PACKAGES"

    init_repo_package_map || {
        print_error "repo-packages: unsupported DISTRO."
        return 1
    }

    local fail=0
    local k
    local pkgs
    local label

    for k in "${REPO_ORDER[@]}"; do
        [[ "${REPO_WANT[$k]:-}" == "1" ]] || continue
        pkgs="${REPO_PKGMAP[$k]:-}"
        [[ -z "$pkgs" ]] && continue
        label="${pkgs// / + }"
        install_package "$pkgs" "repo: $label" || fail=1
    done

    if (( fail )); then
        print_error "One or more repository package installs failed."
        return 1
    fi
    if ! repo_packages_verify_selected; then
        print_error "Post-install verification failed for repository packages."
        return 1
    fi
    if ! repo_packages_configure_selected; then
        print_error "Post-install configuration failed (groups or systemd units)."
        return 1
    fi
    print_success "Repository package installs finished."
}

repo_packages_pick_and_install() {
    repo_packages_prompt_selection
    local ec=$?
    if (( ec == TUI_BACK_TO_MAIN )); then
        return "$ec"
    fi
    (( ec != 0 )) && return 0
    repo_packages_install_selected
}
