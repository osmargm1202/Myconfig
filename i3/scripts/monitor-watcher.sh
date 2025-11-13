#!/usr/bin/env bash
#
# Monitor Watcher - Monitorea cambios en monitores conectados
# Ejecuta el display handler cuando detecta cambios
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Path to handler script
HANDLER_SCRIPT="$HOME/.config/i3/scripts/auto-display-handler.sh"

# Function to get current monitor fingerprint
get_monitor_fingerprint() {
    xrandr --query | grep " connected" | awk '{print $1}' | sort | tr '\n' ' ' | xargs
}

# Initial state
last_fingerprint=$(get_monitor_fingerprint)

# Log file for debugging (optional)
LOG_FILE="$HOME/.cache/monitor-watcher.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_message "Monitor watcher iniciado. Estado inicial: $last_fingerprint"

# Main monitoring loop
while true; do
    sleep 2  # Check every 2 seconds
    
    current_fingerprint=$(get_monitor_fingerprint)
    
    # Check if monitors changed
    if [[ "$current_fingerprint" != "$last_fingerprint" ]]; then
        log_message "Cambio detectado: $last_fingerprint -> $current_fingerprint"
        
        # Before handling the change, save current wallpaper state for all currently connected monitors
        # This ensures we have the correct wallpaper state before monitors disconnect
        WALLPAPER_HELPER="$HOME/.config/i3/scripts/wallpaper-helper.sh"
        if [[ -f "$WALLPAPER_HELPER" ]]; then
            source "$WALLPAPER_HELPER"
            if declare -f get_connected_monitors &>/dev/null && \
               declare -f get_current_wallpaper_for_monitor &>/dev/null && \
               declare -f save_wallpaper_state &>/dev/null; then
                # Get all monitors that are currently connected (before they potentially disconnect)
                local current_monitors
                current_monitors=$(get_connected_monitors)
                # Also check previous state to catch monitors that might disconnect
                local previous_monitors
                previous_monitors=$(echo "$last_fingerprint" | tr ' ' '\n')
                
                # Save state for all monitors that were connected
                while IFS= read -r monitor; do
                    [[ -z "$monitor" ]] && continue
                    # Try to get current wallpaper using xwallpaper or from state
                    # We can't directly query xwallpaper, but we can ensure state is saved
                    local existing_wallpaper
                    existing_wallpaper=$(get_current_wallpaper_for_monitor "$monitor")
                    # If we have a wallpaper in state, it's already saved, so we're good
                    if [[ -z "$existing_wallpaper" ]]; then
                        # Try legacy file as last resort, but only if monitor is still connected
                        if echo "$current_monitors" | grep -q "^$monitor$"; then
                            if [[ -f "$HOME/.config/current_wallpaper" ]]; then
                                local legacy_wallpaper
                                legacy_wallpaper=$(cat "$HOME/.config/current_wallpaper" 2>/dev/null)
                                if [[ -n "$legacy_wallpaper" && -f "$legacy_wallpaper" ]]; then
                                    save_wallpaper_state "$monitor" "$legacy_wallpaper"
                                    log_message "Guardado wallpaper legacy para $monitor: $legacy_wallpaper"
                                fi
                            fi
                        fi
                    fi
                done <<< "$previous_monitors"
            fi
        fi
        
        # Wait a moment for hardware to stabilize
        sleep 1
        
        # Execute handler script
        if [[ -f "$HANDLER_SCRIPT" ]]; then
            log_message "Ejecutando handler: $HANDLER_SCRIPT"
            "$HANDLER_SCRIPT" >> "$LOG_FILE" 2>&1
        else
            log_message "ERROR: Handler script no encontrado: $HANDLER_SCRIPT"
        fi
        
        # Update fingerprint
        last_fingerprint=$(get_monitor_fingerprint)
    fi
done

