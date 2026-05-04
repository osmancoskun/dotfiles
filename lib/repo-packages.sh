# Optional packages from the distribution repositories only (no Google/MS/Cursor repos here).
# Expects: DISTRO, APP_DICT, print_*, install_package, numbered_prompt_apply_line_to_want (numbered-prompt.sh),
#          tui_read_with_back, TUI_BACK_TO_MAIN (tui-back.sh; setup.sh sources it before this file).

declare -gA REPO_WANT=()
declare -gA REPO_PKGMAP=()
declare -ga REPO_ORDER=()
declare -ga REPO_LABELS=()

# Populate REPO_ORDER and REPO_PKGMAP. Call after init_app_dict.
init_repo_package_map() {
    REPO_ORDER=(git openssh nc nettools jq htop ripgrep fd bat zip tree build dnsutils python nodejs yarn pnpm)
    REPO_PKGMAP=()
    REPO_LABELS=()
    case $DISTRO in
        fedora)
            REPO_PKGMAP[git]=git
            REPO_PKGMAP[openssh]=openssh-clients
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
            ;;
        debian)
            REPO_PKGMAP[git]=git
            REPO_PKGMAP[openssh]=openssh-client
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
            ;;
        arch)
            REPO_PKGMAP[git]=git
            REPO_PKGMAP[openssh]=openssh
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
            ;;
        *)
            return 1
            ;;
    esac
    REPO_LABELS=(
        "Git"
        "OpenSSH client (ssh, scp)"
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

    if (( bad )); then
        return 1
    fi
    print_success "Post-install verification passed for selected repository packages."
    return 0
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
