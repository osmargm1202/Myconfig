# Iniciar Niri automáticamente al hacer login en TTY1
if status is-login
    if test -z "$DISPLAY" -a "$XDG_VTNR" -eq 1
        exec niri
    end
end

