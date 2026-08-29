# Managed by dotfiles — stow/link via: ./setup.sh dotfiles (config step)

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_THEME="robbyrussell"

# history-substring-search before syntax-highlighting (OMZ loads in order)
plugins=(
    git
    zsh-autosuggestions
    zsh-history-substring-search
    zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# history-substring-search key bindings (after OMZ sources the plugin)
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

HISTSIZE=50000
SAVEHIST=50000
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"

# Suggestions while typing (gray); accept with Right arrow
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'

# User overrides
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
