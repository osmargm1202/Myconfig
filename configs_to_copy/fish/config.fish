if status is-interactive
    # Commands to run in interactive sessions can go here
end

if status --is-login
    set -gx PATH $PATH ~/linux/bin
end

# Iniciar Niri automáticamente al hacer login en TTY1
if status is-login
    if test -z "$DISPLAY" -a "$XDG_VTNR" -eq 1
        exec niri
    end
end

function start-sway
    # Wayland
    set -x OZONE_PLATFORM wayland
    set -x QT_QPA_PLATFORM wayland
    set -x GDK_BACKEND wayland
    set -x SDL_VIDEODRIVER wayland
    set -x CLUTTER_BACKEND wayland
    
    # NVIDIA específico
    set -x __GLX_VENDOR_LIBRARY_NAME nvidia
    set -x LIBVA_DRIVER_NAME nvidia
    set -x VDPAU_DRIVER nvidia
    set -x NVD_BACKEND direct
    
    # GPU optimization
    set -x __NV_PRIME_RENDER_OFFLOAD 1
    set -x __VK_LAYER_NV_optimus NVIDIA_only
    set -x LIBGL_ALWAYS_INDIRECT 0
    
    # CRÍTICO para Sway + NVIDIA
    set -x WLR_NO_HARDWARE_CURSORS 1
    set -x GBM_BACKEND nvidia-drm
    
    # Electron apps
    set -x ELECTRON_OZONE_PLATFORM_HINT auto
    
    # Performance
    set -x MESA_NO_ERROR 1
    set -x EGL_PLATFORM wayland
    
    # Ejecutar Sway
    exec sway
end

# Alias corto
alias ss='start-sway'

# PATH
set -gx PATH $HOME/.local/bin $PATH

set -gx PATH $HOME/go/bin $PATH

# Prompt más vistoso (starship opcional)
if type -q starship
    starship init fish | source
end

# zoxide (cd inteligente)
zoxide init fish | source
alias cd="z"

# eza (ls mejorado)
alias ls="eza --group-directories-first --icons"
alias ll="eza -la --group-directories-first --icons"
alias lt="eza --tree --group-directories-first --icons"

# ripgrep (buscar rápido)
alias rg="rg --hidden --glob '!.git/*'"

# fd (buscar archivos mejor que find)
alias f="fd --hidden --exclude .git"

# ipinfo (información de IP)
alias ipinfo="curl -s ipinfo.io"

# peaclock (reloj digital con configuración personalizada)
if type -q peaclock
    if test -f ~/.config/peaclock/config
        alias clock="peaclock --config-dir ~/.config/peaclock"
    else
        alias clock="peaclock"
    end
end

set TERM xterm-256color
set EDITOR nvim
set FZF_DEFAULT_OPTS "--height=50% --reverse --inline-info --border --color=fg:15,bg:0"

# history search (ctrl+r mejorado con fzf si lo instalas)
if type -q fzf
    function fish_user_key_bindings
        bind \cr fzf_history
    end
end

# Deshabilitar mensaje de ayuda de fish
set -U fish_greeting ""

function cheat
    curl -s cheat.sh/:list | fzf --preview "curl -s cheat.sh/{}" --preview-window=right:70% | xargs -I {} curl -s cheat.sh/{} | bat --language=markdown --paging=always
end

# Ejecutar fastfetch con configuración ORGMOS (logo orgm.png)
if type -q fastfetch
    if test -f ~/.config/fastfetch/config.jsonc
        fastfetch --config ~/.config/fastfetch/config.jsonc
    else if test -f ~/.config/fastfetch/orgm.png
        fastfetch --logo-path ~/.config/fastfetch/orgm.png
    else
        fastfetch
    end
end

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/osmar/google-cloud-sdk/path.fish.inc' ]
    . '/home/osmar/google-cloud-sdk/path.fish.inc'
end

