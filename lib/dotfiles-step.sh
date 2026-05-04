# Step 4: optional Oh My Zsh and default shell → zsh (no stow for now).
# Expects: print_*, numbered_prompt_apply_line_to_want, tui_read_with_back, TUI_BACK_TO_MAIN,
#          setup_oh_my_zsh (omz.sh), change_shell (shell.sh).

declare -gA DOTFILES_STEP_WANT=()

# CSV keys: omz, chsh
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
            omz | chsh)
                DOTFILES_STEP_WANT["$_p"]=1
                ;;
            *)
                print_warning "Unknown dotfiles step key '$_p' (ignored)."
                ;;
        esac
    done
    local any=0
    for k in omz chsh; do
        [[ "${DOTFILES_STEP_WANT[$k]:-}" == "1" ]] && any=1
    done
    (( any )) || return 1
    return 0
}

dotfiles_step_prompt_selection() {
    DOTFILES_STEP_WANT=()
    print_header "DOTFILES & SHELL"
    print_info "Install git, curl, and zsh from repository packages (menu 2) before this if they are missing."

    local keys=(omz chsh)
    local labels=(
        "Oh My Zsh + common plugins (zsh-autosuggestions, syntax-highlighting, history-substring)"
        "Set default login shell to zsh (chsh)"
    )
    local max=${#keys[@]}
    local i
    print_info ""
    for ((i = 0; i < max; i++)); do
        print_info "  $((i + 1))) ${labels[i]}"
    done
    print_info "  0) All listed above"
    print_info ""
    print_info "Type numbers (spaces or commas), then Enter — e.g. 1 2"
    print_info "B) Back to main menu"
    local line=
    tui_read_with_back "> " line || return $?

    numbered_prompt_apply_line_to_want "$line" "$max" DOTFILES_STEP_WANT "${keys[@]}"

    local any=0
    for k in omz chsh; do
        [[ "${DOTFILES_STEP_WANT[$k]:-}" == "1" ]] && any=1
    done
    if (( any == 0 )); then
        print_info "Nothing selected; skipping."
        return 1
    fi
    return 0
}

# Order: omz before chsh (reasonable default).
dotfiles_step_run_selected() {
    local fail=0

    if [[ "${DOTFILES_STEP_WANT[omz]:-}" == "1" ]]; then
        setup_oh_my_zsh || fail=1
    fi
    if [[ "${DOTFILES_STEP_WANT[chsh]:-}" == "1" ]]; then
        if ! command -v zsh &>/dev/null; then
            print_error "chsh: zsh is not installed. Install zsh (menu 2), then retry."
            fail=1
        else
            change_shell || fail=1
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
