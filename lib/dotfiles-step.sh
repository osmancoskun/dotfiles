# Step 4: zsh → default shell → Oh My Zsh (+ plugins) → dotfiles config.
# Expects: print_*, numbered_prompt_apply_line_to_want, tui_read_with_back, TUI_BACK_TO_MAIN,
#          ensure_zsh_installed, change_shell (shell.sh), setup_oh_my_zsh (omz.sh).

declare -gA DOTFILES_STEP_WANT=()

# CSV keys: zsh, chsh, omz, config
dotfiles_step_set_want_from_csv() {
    local csv=${1:-}
    DOTFILES_STEP_WANT=()
    [[ -z "$csv" ]] && return 1
    local _p
    IFS=',' read -ra _parts <<< "$csv"
    for _p in "${_parts[@]}"; do
        _p="${_p//[$'\t\r\n ']/}"
        [[ -z "$_p" ]] && continue
        case "$_p" in
            zsh | chsh | omz | config)
                DOTFILES_STEP_WANT["$_p"]=1
                ;;
            *)
                print_warning "Unknown dotfiles step key '$_p' (ignored)."
                ;;
        esac
    done
    local any=0
    for k in zsh chsh omz config; do
        [[ "${DOTFILES_STEP_WANT[$k]:-}" == "1" ]] && any=1
    done
    (( any )) || return 1
    return 0
}

dotfiles_step_prompt_selection() {
    DOTFILES_STEP_WANT=()
    print_header "DOTFILES & SHELL"
    print_info "Recommended order: 1 → 2 → 3 → 4 (zsh, default shell, Oh My Zsh, configs)."

    local keys=(zsh chsh omz config)
    local labels=(
        "Install zsh (from distro repos if missing)"
        "Set default login shell to zsh (chsh)"
        "Oh My Zsh + plugins (autosuggestions, syntax-highlighting, history-substring)"
        "Link shell configs (~/.zshrc, ~/.config/foot/foot.ini, ~/.cursor)"
    )
    local max=${#keys[@]}
    local i
    print_info ""
    for ((i = 0; i < max; i++)); do
        print_info "  $((i + 1))) ${labels[i]}"
    done
    print_info "  0) All listed above"
    print_info ""
    print_info "Type numbers (spaces or commas), then Enter — e.g. 1 2 3 4"
    print_info "B) Back to main menu"
    local line=
    tui_read_with_back "> " line || return $?

    numbered_prompt_apply_line_to_want "$line" "$max" DOTFILES_STEP_WANT "${keys[@]}"

    local any=0
    for k in zsh chsh omz config; do
        [[ "${DOTFILES_STEP_WANT[$k]:-}" == "1" ]] && any=1
    done
    if (( any == 0 )); then
        print_info "Nothing selected; skipping."
        return 1
    fi
    return 0
}

# Order: zsh → chsh → omz → config.
dotfiles_step_run_selected() {
    local fail=0
    local root
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    if [[ "${DOTFILES_STEP_WANT[zsh]:-}" == "1" ]]; then
        ensure_zsh_installed || fail=1
    fi
    if [[ "${DOTFILES_STEP_WANT[chsh]:-}" == "1" ]]; then
        if ! command -v zsh &>/dev/null; then
            print_error "chsh: zsh is not installed. Run step 1 (zsh) first."
            fail=1
        else
            change_shell || fail=1
        fi
    fi
    if [[ "${DOTFILES_STEP_WANT[omz]:-}" == "1" ]]; then
        if ! command -v zsh &>/dev/null; then
            print_error "Oh My Zsh: zsh is not installed. Run step 1 (zsh) first."
            fail=1
        elif ! command -v git &>/dev/null || ! command -v curl &>/dev/null; then
            print_error "Oh My Zsh needs git and curl (menu 2)."
            fail=1
        else
            setup_oh_my_zsh || fail=1
        fi
    fi
    if [[ "${DOTFILES_STEP_WANT[config]:-}" == "1" ]]; then
        if ! bash "$root/scripts/setup/shell-config.sh"; then
            fail=1
        fi
    fi

    if (( fail )); then
        return 1
    fi
    return 0
}

dotfiles_step_pick_and_run() {
    dotfiles_step_prompt_selection
    local ec=$?
    if (( ec == TUI_BACK_TO_MAIN )); then
        return "$ec"
    fi
    (( ec != 0 )) && return 0
    dotfiles_step_run_selected
}
