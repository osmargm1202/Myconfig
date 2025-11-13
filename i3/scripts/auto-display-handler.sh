#!/usr/bin/env bash
#
# Auto Display Handler - Maneja cambios automáticos de monitores
# Se ejecuta cuando autorandr detecta un cambio en los monitores conectados
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get number of connected monitors
get_monitor_count() {
    xrandr --query | grep " connected" | wc -l
}

# Get primary monitor
get_primary_monitor() {
    xrandr --query | grep " connected" | grep "primary" | awk '{print $1}' | head -n1
}

# Get first connected monitor (fallback)
get_first_monitor() {
    xrandr --query | grep " connected" | awk '{print $1}' | head -n1
}

# Apply single monitor default configuration
apply_single_monitor_config() {
    local primary
    primary=$(get_primary_monitor)
    
    if [[ -z "$primary" ]]; then
        primary=$(get_first_monitor)
    fi
    
    if [[ -z "$primary" ]]; then
        echo -e "${RED}No se encontraron monitores conectados${NC}"
        return 1
    fi
    
    # Get the best resolution for the monitor
    local mode
    mode=$(xrandr --query | grep -A 1 "^$primary" | grep -v "^$primary" | grep -v "^--" | awk '{print $1}' | head -n1)
    
    if [[ -z "$mode" ]]; then
        echo -e "${YELLOW}No se pudo detectar el modo de resolución para $primary${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Aplicando configuración de un solo monitor: $primary${NC}"
    
    # Disable all other monitors and set primary
    xrandr --output "$primary" --mode "$mode" --primary
    
    # Disable all disconnected monitors
    while IFS= read -r line; do
        local monitor=$(echo "$line" | awk '{print $1}')
        if [[ "$monitor" != "$primary" ]]; then
            xrandr --output "$monitor" --off 2>/dev/null
        fi
    done < <(xrandr --query | grep " disconnected" | awk '{print $1}')
    
    # Restart polybar to adjust to new monitor setup
    sleep 0.5
    if pgrep polybar &>/dev/null; then
        polybar-msg cmd restart 2>/dev/null || true
    else
        # Start polybar if not running
        if [[ -f "$HOME/.config/polybar/config.ini" ]]; then
            polybar --config="$HOME/.config/polybar/config.ini" modern &
        fi
    fi
    
    # Wallpapers are now only managed manually through the wallpaper selector
    # No automatic wallpaper restoration when monitors change
    
    if command -v notify-send &>/dev/null; then
        notify-send "Display Manager" "Configuración de un solo monitor aplicada: $primary" -t 2000 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Configuración de un solo monitor aplicada${NC}"
    return 0
}

# Main handler function
handle_display_change() {
    local monitor_count
    monitor_count=$(get_monitor_count)
    
    echo -e "${BLUE}Cambio de monitor detectado. Monitores conectados: $monitor_count${NC}"
    
    if [[ $monitor_count -eq 0 ]]; then
        echo -e "${YELLOW}No hay monitores conectados${NC}"
        return 1
    elif [[ $monitor_count -eq 1 ]]; then
        # Single monitor - apply default configuration
        echo -e "${BLUE}Un solo monitor detectado, aplicando configuración por defecto...${NC}"
        apply_single_monitor_config
    else
        # Multiple monitors - try to load matching profile first, then open display manager
        echo -e "${BLUE}Múltiples monitores detectados ($monitor_count)${NC}"
        
        # Wait a moment for monitors to stabilize
        sleep 1
        
        # Try to automatically match and load a profile
        local matched_profile
        matched_profile=$(autorandr --match-edid --change 2>/dev/null)
        
        if [[ $? -eq 0 && -n "$matched_profile" ]]; then
            echo -e "${GREEN}Perfil automático cargado: $matched_profile${NC}"
            if command -v notify-send &>/dev/null; then
                notify-send "Display Manager" "Perfil automático cargado: $matched_profile" -t 2000 2>/dev/null || true
            fi
        else
            # No matching profile found - open display manager for user to select
            echo -e "${BLUE}No se encontró perfil automático, abriendo gestor de configuraciones...${NC}"
            
            # Open display manager in background (non-blocking) for user to select profile
            if [[ -f "$HOME/.config/i3/scripts/display-manager.sh" ]]; then
                # Use DISPLAY environment to ensure it runs in the correct X session
                # Run in a new terminal so user can interact
                if command -v kitty &>/dev/null; then
                    DISPLAY=${DISPLAY:-:0} kitty -e "$HOME/.config/i3/scripts/display-manager.sh" &
                else
                    DISPLAY=${DISPLAY:-:0} "$HOME/.config/i3/scripts/display-manager.sh" &
                fi
            else
                echo -e "${RED}Display manager no encontrado${NC}"
                # Fallback: try to load first available profile
                local profiles
                profiles=$(autorandr --list 2>/dev/null)
                if [[ -n "$profiles" ]]; then
                    local auto_profile=$(echo "$profiles" | head -n1)
                    if [[ -n "$auto_profile" ]]; then
                        echo -e "${BLUE}Intentando cargar perfil: $auto_profile${NC}"
                        autorandr --load "$auto_profile" 2>/dev/null
                    fi
                fi
            fi
        fi
    fi
}

# Run handler
handle_display_change

