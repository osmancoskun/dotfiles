# Numbered multi-select: user types 1 3 5 or 1,3,5 and presses Enter.
# Token 0 selects all keys (same order as passed to this function).

# Args: $1 = line from user, $2 = max index (1-based), $3 = name of associative array to fill,
#       remaining args = keys in display order (index 1 = first key).
numbered_prompt_apply_line_to_want() {
    local line=$1
    local max=$2
    local want_name=$3
    shift 3
    local -a keys=("$@")
    local -n wantref="$want_name"

    wantref=()

    line="${line//,/ }"
    line="${line//[$'\t\r']/ }"

    local tok all=0
    for tok in $line; do
        [[ -z "$tok" ]] && continue
        if [[ "$tok" == "0" ]]; then
            all=1
            break
        fi
    done

    if (( all )); then
        local k
        for k in "${keys[@]}"; do
            wantref[$k]=1
        done
        return 0
    fi

    for tok in $line; do
        [[ -z "$tok" ]] && continue
        if ! [[ "$tok" =~ ^[0-9]+$ ]]; then
            print_warning "Ignoring non-numeric token: $tok"
            continue
        fi
        if (( tok < 1 || tok > max )); then
            print_warning "Ignoring out-of-range number: $tok (use 1–$max, or 0 for all)"
            continue
        fi
        wantref["${keys[$((tok - 1))]}"]=1
    done
}
