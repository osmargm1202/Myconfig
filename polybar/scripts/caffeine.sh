#!/bin/bash
#
# Script para polybar que muestra el estado del modo cafeína
# Muestra iconos de Nerd Fonts: 󰒲 cuando está activado, 󰂎 cuando está desactivado
#

STATE_FILE="$HOME/.config/i3/caffeine_state"
CAFFEINE_SCRIPT="$HOME/.config/i3/scripts/caffeine.sh"

# Si se pasa "toggle" como argumento, hacer toggle
if [[ "${1:-}" == "toggle" ]]; then
    "$CAFFEINE_SCRIPT" toggle
    # Esperar un momento para que el estado se actualice
    sleep 0.2
fi

# Leer el estado
if [[ -f "$STATE_FILE" ]]; then
    state=$(cat "$STATE_FILE")
else
    state="enabled"  # Default: activado
fi

# Mostrar el icono correspondiente (Nerd Fonts)
if [[ "$state" == "enabled" ]]; then
    echo "󰒲"  # nf-md-coffee (café)
else
    echo "󰂎"  # nf-md-battery-outline (batería outline)
fi

