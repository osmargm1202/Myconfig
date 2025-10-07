if status is-interactive
    # Commands to run in interactive sessions can go here
end

# PATH
set -gx PATH $HOME/.local/bin $PATH

# Prompt más vistoso (starship opcional)
if type -q starship
    starship init fish | source
end

# zoxide (cd inteligente)
zoxide init fish | source
alias cd="z"

# eza (ls mejorado)
alias ls="eza --group-directories-first --icons"
alias ll="eza -l --group-directories-first --icons"
alias la="eza -la --group-directories-first --icons"

# ripgrep (buscar rápido)
alias rg="rg --hidden --glob '!.git/*'"

# fd (buscar archivos mejor que find)
alias f="fd --hidden --exclude .git"
set TERM xterm-256color
set EDITOR nvim
set FZF_DEFAULT_OPTS "--height=50% --reverse --inline-info --border --color=fg:15,bg:0"

# history search (ctrl+r mejorado con fzf si lo instalas)
if type -q fzf
    function fish_user_key_bindings
        bind \cr fzf_history
    end
end

fastfetch

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/osmar/google-cloud-sdk/path.fish.inc' ]; . '/home/osmar/google-cloud-sdk/path.fish.inc'; end