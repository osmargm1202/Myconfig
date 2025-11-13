#!/usr/bin/env bash
#
# Display Manager - Gestor de configuraciones de pantalla
# Usa autorandr para guardar/cargar perfiles y xrandr para configuraciones rápidas
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Gum color configuration
export GUM_CHOOSE_SELECTED_FOREGROUND="#87CEEB"  # Sky Blue para selección
export GUM_CHOOSE_CURSOR_FOREGROUND="#87CEEB"    # Sky Blue para cursor
export GUM_CHOOSE_HEADER_FOREGROUND="#0000FF"    # Azul para títulos
export GUM_INPUT_CURSOR_FOREGROUND="#87CEEB"
export GUM_INPUT_PROMPT_FOREGROUND="#0000FF"     # Azul para prompts
export GUM_CONFIRM_SELECTED_FOREGROUND="#87CEEB"

# Check dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v gum &>/dev/null; then
        missing+=("gum")
    fi
    
    if ! command -v autorandr &>/dev/null; then
        missing+=("autorandr")
    fi
    
    if ! command -v xrandr &>/dev/null; then
        missing+=("xrandr")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Error: Faltan dependencias: ${missing[*]}${NC}"
        echo -e "${YELLOW}Instala con: sudo pacman -S ${missing[*]}${NC}"
        exit 1
    fi
}

# Get list of connected displays
get_displays() {
    xrandr --query | grep " connected" | awk '{print $1}'
}

# Get primary display
get_primary_display() {
    xrandr --query | grep " connected" | grep "primary" | awk '{print $1}' | head -n1
}

# Get first connected display (fallback if no primary)
get_first_display() {
    xrandr --query | grep " connected" | awk '{print $1}' | head -n1
}

# Get second connected display
get_second_display() {
    xrandr --query | grep " connected" | awk '{print $1}' | tail -n +2 | head -n1
}

# Save current configuration as profile
save_profile() {
    local profile_name
    profile_name=$(gum input --placeholder "Nombre del perfil (ej: home, office, dual)" --prompt "Nombre: ")
    
    if [[ -z "$profile_name" ]]; then
        gum style --foreground="$RED" "Operación cancelada"
        return 1
    fi
    
    # Check if profile already exists
    local existing_profiles
    existing_profiles=$(autorandr --list 2>/dev/null)
    
    if echo "$existing_profiles" | grep -q "^$profile_name$"; then
        echo -e "${YELLOW}El perfil '$profile_name' ya existe${NC}"
        if gum confirm "¿Sobrescribir el perfil existente '$profile_name'?"; then
            echo -e "${BLUE}Guardando configuración como: $profile_name (sobrescribiendo)${NC}"
            if autorandr --save "$profile_name" --force; then
                gum style --foreground="$GREEN" "✓ Perfil '$profile_name' guardado exitosamente (sobrescrito)"
                notify-send "Display Manager" "Perfil '$profile_name' guardado (sobrescrito)" -t 2000 2>/dev/null || true
            else
                gum style --foreground="$RED" "✗ Error al guardar el perfil"
                return 1
            fi
        else
            gum style --foreground="$YELLOW" "Operación cancelada"
            return 1
        fi
    else
        echo -e "${BLUE}Guardando configuración como: $profile_name${NC}"
        if autorandr --save "$profile_name"; then
            gum style --foreground="$GREEN" "✓ Perfil '$profile_name' guardado exitosamente"
            notify-send "Display Manager" "Perfil '$profile_name' guardado" -t 2000 2>/dev/null || true
        else
            gum style --foreground="$RED" "✗ Error al guardar el perfil"
            return 1
        fi
    fi
}

# Load saved profile
load_profile() {
    local profiles
    profiles=$(autorandr --list 2>/dev/null)
    
    if [[ -z "$profiles" ]]; then
        gum style --foreground="$YELLOW" "No hay perfiles guardados"
        return 1
    fi
    
    local selected
    selected=$(echo "$profiles" | gum choose --header "Selecciona un perfil para cargar")
    
    if [[ -z "$selected" ]]; then
        return 1
    fi
    
    echo -e "${BLUE}Cargando perfil: $selected${NC}"
    
    if autorandr --load "$selected"; then
        gum style --foreground="$GREEN" "✓ Perfil '$selected' cargado exitosamente"
        notify-send "Display Manager" "Perfil '$selected' cargado" -t 2000 2>/dev/null || true
    else
        gum style --foreground="$RED" "✗ Error al cargar el perfil"
        return 1
    fi
}

# Delete profile
delete_profile() {
    local profiles
    profiles=$(autorandr --list 2>/dev/null)
    
    if [[ -z "$profiles" ]]; then
        gum style --foreground="$YELLOW" "No hay perfiles guardados"
        return 1
    fi
    
    local selected
    selected=$(echo "$profiles" | gum choose --header "Selecciona un perfil para eliminar")
    
    if [[ -z "$selected" ]]; then
        return 1
    fi
    
    if gum confirm "¿Eliminar el perfil '$selected'?"; then
        if autorandr --remove "$selected"; then
            gum style --foreground="$GREEN" "✓ Perfil '$selected' eliminado"
            notify-send "Display Manager" "Perfil '$selected' eliminado" -t 2000 2>/dev/null || true
        else
            gum style --foreground="$RED" "✗ Error al eliminar el perfil"
            return 1
        fi
    fi
}

# Quick configuration: Duplicate displays
quick_duplicate() {
    local primary
    primary=$(get_primary_display)
    
    if [[ -z "$primary" ]]; then
        primary=$(get_first_display)
    fi
    
    if [[ -z "$primary" ]]; then
        gum style --foreground="$RED" "No se encontraron monitores conectados"
        return 1
    fi
    
    local mode
    mode=$(xrandr --query | grep -A 1 "^$primary" | grep -v "^$primary" | grep -v "^--" | awk '{print $1}' | head -n1)
    
    if [[ -z "$mode" ]]; then
        gum style --foreground="$RED" "No se pudo detectar el modo de resolución"
        return 1
    fi
    
    echo -e "${BLUE}Duplicando pantallas...${NC}"
    
    # Get all connected displays
    local displays
    while IFS= read -r line; do
        [[ -n "$line" ]] && displays+=("$line")
    done < <(get_displays)
    
    local cmd="xrandr"
    local first=true
    
    for display in "${displays[@]}"; do
        if [[ "$first" == true ]]; then
            cmd="$cmd --output $display --mode $mode"
            first=false
        else
            cmd="$cmd --output $display --mode $mode --same-as $primary"
        fi
    done
    
    if eval "$cmd"; then
        gum style --foreground="$GREEN" "✓ Pantallas duplicadas"
        notify-send "Display Manager" "Pantallas duplicadas" -t 2000 2>/dev/null || true
    else
        gum style --foreground="$RED" "✗ Error al duplicar pantallas"
        return 1
    fi
}

# Quick configuration: Monitor to the left
quick_left() {
    local primary
    primary=$(get_primary_display)
    
    if [[ -z "$primary" ]]; then
        primary=$(get_first_display)
    fi
    
    local secondary
    secondary=$(get_second_display)
    
    if [[ -z "$secondary" ]]; then
        gum style --foreground="$YELLOW" "Se necesita al menos 2 monitores para esta configuración"
        return 1
    fi
    
    local primary_mode
    primary_mode=$(xrandr --query | grep -A 1 "^$primary" | grep -v "^$primary" | grep -v "^--" | awk '{print $1}' | head -n1)
    
    local secondary_mode
    secondary_mode=$(xrandr --query | grep -A 1 "^$secondary" | grep -v "^$secondary" | grep -v "^--" | awk '{print $1}' | head -n1)
    
    echo -e "${BLUE}Configurando $secondary a la izquierda de $primary...${NC}"
    
    if xrandr --output "$primary" --mode "$primary_mode" --primary \
              --output "$secondary" --mode "$secondary_mode" --left-of "$primary"; then
        gum style --foreground="$GREEN" "✓ Monitor configurado a la izquierda"
        notify-send "Display Manager" "Monitor configurado a la izquierda" -t 2000 2>/dev/null || true
    else
        gum style --foreground="$RED" "✗ Error al configurar monitores"
        return 1
    fi
}

# Quick configuration: Monitor to the right
quick_right() {
    local primary
    primary=$(get_primary_display)
    
    if [[ -z "$primary" ]]; then
        primary=$(get_first_display)
    fi
    
    local secondary
    secondary=$(get_second_display)
    
    if [[ -z "$secondary" ]]; then
        gum style --foreground="$YELLOW" "Se necesita al menos 2 monitores para esta configuración"
        return 1
    fi
    
    local primary_mode
    primary_mode=$(xrandr --query | grep -A 1 "^$primary" | grep -v "^$primary" | grep -v "^--" | awk '{print $1}' | head -n1)
    
    local secondary_mode
    secondary_mode=$(xrandr --query | grep -A 1 "^$secondary" | grep -v "^$secondary" | grep -v "^--" | awk '{print $1}' | head -n1)
    
    echo -e "${BLUE}Configurando $secondary a la derecha de $primary...${NC}"
    
    if xrandr --output "$primary" --mode "$primary_mode" --primary \
              --output "$secondary" --mode "$secondary_mode" --right-of "$primary"; then
        gum style --foreground="$GREEN" "✓ Monitor configurado a la derecha"
        notify-send "Display Manager" "Monitor configurado a la derecha" -t 2000 2>/dev/null || true
    else
        gum style --foreground="$RED" "✗ Error al configurar monitores"
        return 1
    fi
}

# Quick configuration: Monitor above
quick_above() {
    local primary
    primary=$(get_primary_display)
    
    if [[ -z "$primary" ]]; then
        primary=$(get_first_display)
    fi
    
    local secondary
    secondary=$(get_second_display)
    
    if [[ -z "$secondary" ]]; then
        gum style --foreground="$YELLOW" "Se necesita al menos 2 monitores para esta configuración"
        return 1
    fi
    
    local primary_mode
    primary_mode=$(xrandr --query | grep -A 1 "^$primary" | grep -v "^$primary" | grep -v "^--" | awk '{print $1}' | head -n1)
    
    local secondary_mode
    secondary_mode=$(xrandr --query | grep -A 1 "^$secondary" | grep -v "^$secondary" | grep -v "^--" | awk '{print $1}' | head -n1)
    
    echo -e "${BLUE}Configurando $secondary arriba de $primary...${NC}"
    
    if xrandr --output "$primary" --mode "$primary_mode" --primary \
              --output "$secondary" --mode "$secondary_mode" --above "$primary"; then
        gum style --foreground="$GREEN" "✓ Monitor configurado arriba"
        notify-send "Display Manager" "Monitor configurado arriba" -t 2000 2>/dev/null || true
    else
        gum style --foreground="$RED" "✗ Error al configurar monitores"
        return 1
    fi
}

# Quick configuration: Monitor below
quick_below() {
    local primary
    primary=$(get_primary_display)
    
    if [[ -z "$primary" ]]; then
        primary=$(get_first_display)
    fi
    
    local secondary
    secondary=$(get_second_display)
    
    if [[ -z "$secondary" ]]; then
        gum style --foreground="$YELLOW" "Se necesita al menos 2 monitores para esta configuración"
        return 1
    fi
    
    local primary_mode
    primary_mode=$(xrandr --query | grep -A 1 "^$primary" | grep -v "^$primary" | grep -v "^--" | awk '{print $1}' | head -n1)
    
    local secondary_mode
    secondary_mode=$(xrandr --query | grep -A 1 "^$secondary" | grep -v "^$secondary" | grep -v "^--" | awk '{print $1}' | head -n1)
    
    echo -e "${BLUE}Configurando $secondary abajo de $primary...${NC}"
    
    if xrandr --output "$primary" --mode "$primary_mode" --primary \
              --output "$secondary" --mode "$secondary_mode" --below "$primary"; then
        gum style --foreground="$GREEN" "✓ Monitor configurado abajo"
        notify-send "Display Manager" "Monitor configurado abajo" -t 2000 2>/dev/null || true
    else
        gum style --foreground="$RED" "✗ Error al configurar monitores"
        return 1
    fi
}

# Quick configurations menu
quick_config_menu() {
    while true; do
        local choice
        choice=$(gum choose --header "Configuraciones Rápidas" \
            "• Duplicar monitores" \
            "• Monitor a la izquierda" \
            "• Monitor a la derecha" \
            "• Monitor arriba" \
            "• Monitor abajo" \
            "• Volver")
        
        case "$choice" in
            "• Duplicar monitores")
                quick_duplicate
                sleep 1
                ;;
            "• Monitor a la izquierda")
                quick_left
                sleep 1
                ;;
            "• Monitor a la derecha")
                quick_right
                sleep 1
                ;;
            "• Monitor arriba")
                quick_above
                sleep 1
                ;;
            "• Monitor abajo")
                quick_below
                sleep 1
                ;;
            "• Volver"|"")
                return 0
                ;;
        esac
    done
}

# Main menu
main_menu() {
    while true; do
        local choice
        choice=$(gum choose --header "Gestor de Configuraciones de Pantalla" \
            "• Guardar configuración actual" \
            "• Cargar perfil guardado" \
            "• Eliminar perfil" \
            "• Configuraciones rápidas" \
            "• Salir")
        
        case "$choice" in
            "• Guardar configuración actual")
                save_profile
                sleep 1
                ;;
            "• Cargar perfil guardado")
                load_profile
                sleep 1
                ;;
            "• Eliminar perfil")
                delete_profile
                sleep 1
                ;;
            "• Configuraciones rápidas")
                quick_config_menu
                ;;
            "• Salir"|"")
                exit 0
                ;;
        esac
    done
}

# Check if we have a TTY available
# When run from i3, we might not have /dev/tty, but we should have stdin
if [[ ! -t 0 ]] && [[ ! -c /dev/tty ]]; then
    echo -e "${RED}Error: Este script requiere una terminal interactiva${NC}"
    echo -e "${YELLOW}Ejecuta desde una terminal o usa el atajo Win+Shift+P${NC}"
    exit 1
fi

# Start the application
check_dependencies
main_menu

