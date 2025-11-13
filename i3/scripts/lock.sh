#!/bin/bash
#
# i3lock script optimizado - lock inmediato
# Requires i3lock-color for advanced features
#

# Tokyo Night colors
bg_color="1a1b26"
fg_color="c0caf5"
primary="7aa2f7"
secondary="bb9af7"
accent="73daca"
warning="e0af68"
alert="f7768e"
success="9ece6a"

# Check if i3lock-color is installed
if ! command -v i3lock &> /dev/null; then
    notify-send "Error" "i3lock no está instalado. Instálalo con: yay -S i3lock-color"
    exit 1
fi

# Usar screenshot solo si está disponible, sino usar color sólido
screenshot_path="/tmp/i3lock_screenshot.png"
use_screenshot=false

# Intentar tomar screenshot de forma rápida (en background)
if command -v maim &> /dev/null; then
    # maim es más rápido que scrot
    maim "$screenshot_path" 2>/dev/null && use_screenshot=true
elif command -v scrot &> /dev/null; then
    scrot -q 50 "$screenshot_path" 2>/dev/null && use_screenshot=true
fi

# Si tenemos screenshot, aplicar blur en background (no bloquea)
if [[ "$use_screenshot" == true ]] && command -v convert &> /dev/null; then
    blurred_path="/tmp/i3lock_blurred.png"
    # Aplicar blur más rápido (menos intenso)
    convert "$screenshot_path" -blur 0x4 "$blurred_path" 2>/dev/null &
    blur_pid=$!
fi

# Check if we have i3lock-color for advanced features
if command -v i3lock-color &> /dev/null; then
    # Si tenemos screenshot con blur, usarlo, sino usar color sólido
    if [[ "$use_screenshot" == true ]] && [[ -f "$blurred_path" ]]; then
        # Esperar un momento para que el blur termine (máximo 0.5 segundos)
        wait $blur_pid 2>/dev/null || sleep 0.3
        lock_image="$blurred_path"
    else
        # Usar color sólido - mucho más rápido
        lock_image=""
    fi
    
    # Advanced lock with i3lock-color
    if [[ -n "$lock_image" ]]; then
        i3lock \
            --image="$lock_image" \
            --tiling \
            --ignore-empty-password \
            --show-failed-attempts \
            --insidever-color="00000000" \
            --insidewrong-color="$alert"88 \
            --inside-color="00000000" \
            --ringver-color="$success"88 \
            --ringwrong-color="$alert"88 \
            --ring-color="$primary"88 \
            --line-uses-ring \
            --keyhl-color="$accent"88 \
            --bshl-color="$warning"88 \
            --separator-color="00000000" \
            --verif-color="$fg_color"ff \
            --wrong-color="$alert"ff \
            --time-color="$fg_color"ff \
            --date-color="$secondary"ff \
            --layout-color="$accent"ff \
            --verif-text="Verificando..." \
            --wrong-text="¡Incorrecto!" \
            --noinput-text="Sin entrada" \
            --lock-text="Bloqueando..." \
            --lockfailed-text="¡Fallo al bloquear!" \
            --time-str="%H:%M:%S" \
            --date-str="%A, %d de %B" \
            --time-font="JetBrainsMono Nerd Font" \
            --date-font="JetBrainsMono Nerd Font" \
            --layout-font="JetBrainsMono Nerd Font" \
            --verif-font="JetBrainsMono Nerd Font" \
            --wrong-font="JetBrainsMono Nerd Font" \
            --radius=120 \
            --ring-width=10 \
            --clock \
            --indicator \
            --time-size=32 \
            --date-size=18 \
            --verif-size=16 \
            --wrong-size=16 \
            --modif-size=16 \
            --pass-media-keys \
            --pass-screen-keys \
            --pass-volume-keys \
            --blur=5
    else
        # Lock con color sólido - instantáneo
        i3lock \
            --color="$bg_color" \
            --ignore-empty-password \
            --show-failed-attempts \
            --insidever-color="00000000" \
            --insidewrong-color="$alert"88 \
            --inside-color="00000000" \
            --ringver-color="$success"88 \
            --ringwrong-color="$alert"88 \
            --ring-color="$primary"88 \
            --line-uses-ring \
            --keyhl-color="$accent"88 \
            --bshl-color="$warning"88 \
            --separator-color="00000000" \
            --verif-color="$fg_color"ff \
            --wrong-color="$alert"ff \
            --time-color="$fg_color"ff \
            --date-color="$secondary"ff \
            --layout-color="$accent"ff \
            --verif-text="Verificando..." \
            --wrong-text="¡Incorrecto!" \
            --noinput-text="Sin entrada" \
            --lock-text="Bloqueando..." \
            --lockfailed-text="¡Fallo al bloquear!" \
            --time-str="%H:%M:%S" \
            --date-str="%A, %d de %B" \
            --time-font="JetBrainsMono Nerd Font" \
            --date-font="JetBrainsMono Nerd Font" \
            --layout-font="JetBrainsMono Nerd Font" \
            --verif-font="JetBrainsMono Nerd Font" \
            --wrong-font="JetBrainsMono Nerd Font" \
            --radius=120 \
            --ring-width=10 \
            --clock \
            --indicator \
            --time-size=32 \
            --date-size=18 \
            --verif-size=16 \
            --wrong-size=16 \
            --modif-size=16 \
            --pass-media-keys \
            --pass-screen-keys \
            --pass-volume-keys
    fi
else
    # Fallback to regular i3lock
    if [[ "$use_screenshot" == true ]] && [[ -f "$screenshot_path" ]]; then
        i3lock -i "$screenshot_path" -t -e
    else
        i3lock -c "$bg_color" -t -e
    fi
fi

# Clean up en background (no bloquea)
rm -f "$screenshot_path" "$blurred_path" &
