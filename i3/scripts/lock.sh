#!/bin/bash
#
# i3lock script with blur and transparency
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

# Take screenshot and apply blur effect
screenshot_path="/tmp/i3lock_screenshot.png"
blurred_path="/tmp/i3lock_blurred.png"

# Capture screenshot
scrot "$screenshot_path"

# Apply blur effect (requires imagemagick)
if command -v convert &> /dev/null; then
    convert "$screenshot_path" -blur 0x8 "$blurred_path"
    rm "$screenshot_path"
    screenshot_path="$blurred_path"
fi

# Check if we have i3lock-color for advanced features
if command -v i3lock-color &> /dev/null; then
    # Advanced lock with i3lock-color
    i3lock \
        --image="$screenshot_path" \
        --tiling \
        --ignore-empty-password \
        --show-failed-attempts \
        \
        --insidever-color="00000000" \
        --insidewrong-color="$alert"88 \
        --inside-color="00000000" \
        \
        --ringver-color="$success"88 \
        --ringwrong-color="$alert"88 \
        --ring-color="$primary"88 \
        \
        --line-uses-ring \
        --keyhl-color="$accent"88 \
        --bshl-color="$warning"88 \
        --separator-color="00000000" \
        \
        --verif-color="$fg_color"ff \
        --wrong-color="$alert"ff \
        --time-color="$fg_color"ff \
        --date-color="$secondary"ff \
        --layout-color="$accent"ff \
        \
        --verif-text="Verificando..." \
        --wrong-text="¡Incorrecto!" \
        --noinput-text="Sin entrada" \
        --lock-text="Bloqueando..." \
        --lockfailed-text="¡Fallo al bloquear!" \
        \
        --time-str="%H:%M:%S" \
        --date-str="%A, %d de %B" \
        --time-font="JetBrainsMono Nerd Font" \
        --date-font="JetBrainsMono Nerd Font" \
        --layout-font="JetBrainsMono Nerd Font" \
        --verif-font="JetBrainsMono Nerd Font" \
        --wrong-font="JetBrainsMono Nerd Font" \
        \
        --radius=120 \
        --ring-width=10 \
        --inside-color="00000000" \
        --ring-color="$primary"88 \
        \
        --clock \
        --indicator \
        --time-size=32 \
        --date-size=18 \
        --verif-size=16 \
        --wrong-size=16 \
        --modif-size=16 \
        \
        --pass-media-keys \
        --pass-screen-keys \
        --pass-volume-keys \
        \
        --blur=5
else
    # Fallback to regular i3lock
    i3lock -i "$screenshot_path" -t -e
fi

# Clean up
rm -f "$screenshot_path" "$blurred_path"