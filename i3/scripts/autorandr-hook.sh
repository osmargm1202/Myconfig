#!/usr/bin/env bash
#
# Autorandr Hook - Se ejecuta cuando autorandr detecta un cambio de monitor
# Este script llama a auto-display-handler.sh para manejar el cambio
#

# Path to the auto display handler script
AUTO_HANDLER="$HOME/.config/i3/scripts/auto-display-handler.sh"

# Execute the handler if it exists
if [[ -f "$AUTO_HANDLER" ]]; then
    # Run in background to avoid blocking autorandr
    "$AUTO_HANDLER" &
fi

