#!/bin/bash

# i3 Hotkey Helper - Show all keybindings in rofi
# Usage: ./hotkey.sh

CONFIG_FILE="$HOME/.config/i3/config"
HOTKEYS_FILE="$HOME/.config/i3/hotkeys.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color


# Function to generate hotkeys list
generate_hotkeys() {
    local config_file="$1"
    local hotkeys_file="$2"
    
    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}Error: i3 config file not found at $config_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Generando lista de hotkeys...${NC}"
    
    # Create hotkeys file
    > "$hotkeys_file"
    
    # Extract keybindings and format them
    grep "^bindsym" "$config_file" | while IFS= read -r line; do
        # Extract key combination and command
        local key_combo=$(echo "$line" | sed 's/bindsym //' | sed 's/ .*//')
        local command=$(echo "$line" | sed 's/.*bindsym [^ ]* //')
        
        # Remove --no-startup-id flag if present
        command=$(echo "$command" | sed 's/--no-startup-id //g')
        
        # Replace $mod with Super for better readability
        key_combo=$(echo "$key_combo" | sed 's/\$mod/Super/g')
        
        # Create description based on command
        local description=""
        case "$command" in
            *"exec"*)
                # Extract executable name for better description
                local exec_name=$(echo "$command" | sed 's/.*exec[^-]*//' | awk '{print $1}' | sed 's/.*\///')
                
                # Handle special cases first
                if [[ "$command" == *"pactl set-sink-volume"* ]]; then
                    if [[ "$command" == *"+"* ]]; then
                        description="Subir volumen"
                    else
                        description="Bajar volumen"
                    fi
                elif [[ "$command" == *"pactl set-sink-mute"* ]]; then
                    description="Silenciar/Activar volumen"
                elif [[ "$command" == *"pactl set-source-mute"* ]]; then
                    description="Silenciar/Activar micrófono"
                elif [[ "$command" == *"rofi -show drun"* ]]; then
                    description="Abrir lanzador de aplicaciones"
                elif [[ "$command" == *"rofi -show window"* ]]; then
                    description="Mostrar ventanas"
                elif [[ "$command" == *"clipmenu"* ]]; then
                    description="Portapapeles"
                elif [[ "$command" == *"flameshot"* ]]; then
                    description="Captura de pantalla"
                elif [[ "$command" == *"steam"* ]]; then
                    description="Abrir Steam"
                elif [[ "$command" == *"discord"* ]]; then
                    description="Abrir Discord"
                elif [[ "$command" == *"systemctl suspend"* ]]; then
                    description="Suspender sistema"
                elif [[ "$command" == *"poweroff"* ]]; then
                    description="Apagar sistema"
                elif [[ "$command" == *"setxkbmap"* ]]; then
                    description="Cambiar teclado"
                elif [[ "$command" == *"game-mode.sh"* ]]; then
                    description="Modo juego"
                elif [[ "$command" == *"change-wallpaper.sh"* ]]; then
                    description="Cambiar fondo de pantalla"
                elif [[ "$command" == *"lock.sh"* ]]; then
                    description="Bloquear pantalla"
                elif [[ "$command" == *"hotkey.sh"* ]]; then
                    description="Mostrar hotkeys"
                else
                    case "$exec_name" in
                        "$term") description="Abrir terminal" ;;
                        "$browser") description="Abrir navegador" ;;
                        "$file-manager") description="Abrir gestor de archivos" ;;
                        "$editor") description="Abrir editor" ;;
                        *) description="Ejecutar: $exec_name" ;;
                    esac
                fi
                ;;
            *"kill"*)
                description="Cerrar ventana"
                ;;
            *"focus"*)
                local direction=$(echo "$command" | awk '{print $2}')
                case "$direction" in
                    "left") description="Enfocar ventana izquierda" ;;
                    "right") description="Enfocar ventana derecha" ;;
                    "up") description="Enfocar ventana superior" ;;
                    "down") description="Enfocar ventana inferior" ;;
                    "parent") description="Enfocar ventana padre" ;;
                esac
                ;;
            *"move"*)
                local direction=$(echo "$command" | awk '{print $2}')
                case "$direction" in
                    "left") description="Mover ventana izquierda" ;;
                    "right") description="Mover ventana derecha" ;;
                    "up") description="Mover ventana superior" ;;
                    "down") description="Mover ventana inferior" ;;
                esac
                ;;
            *"split"*)
                local direction=$(echo "$command" | awk '{print $2}')
                case "$direction" in
                    "h") description="Dividir horizontalmente" ;;
                    "v") description="Dividir verticalmente" ;;
                esac
                ;;
            *"fullscreen"*)
                description="Pantalla completa"
                ;;
            *"layout"*)
                local layout=$(echo "$command" | awk '{print $2}')
                case "$layout" in
                    "stacking") description="Layout apilado" ;;
                    "tabbed") description="Layout pestañas" ;;
                    "toggle") description="Alternar layout" ;;
                esac
                ;;
            *"floating"*)
                description="Alternar ventana flotante"
                ;;
            *"workspace"*)
                local workspace=$(echo "$command" | sed 's/.*workspace number \$ws//')
                description="Ir al workspace $workspace"
                ;;
            *"move container to workspace"*)
                local workspace=$(echo "$command" | sed 's/.*workspace number \$ws//')
                description="Mover ventana al workspace $workspace"
                ;;
            *"reload"*)
                description="Recargar configuración i3"
                ;;
            *"restart"*)
                description="Reiniciar i3"
                ;;
            *"exit"*)
                description="Salir de i3"
                ;;
            *"mode"*)
                local mode=$(echo "$command" | awk '{print $2}' | tr -d '"')
                description="Cambiar a modo: $mode"
                ;;
            *"volume"*)
                if [[ "$command" == *"+"* ]]; then
                    description="Subir volumen"
                elif [[ "$command" == *"-"* ]]; then
                    description="Bajar volumen"
                elif [[ "$command" == *"toggle"* ]]; then
                    description="Silenciar/Activar volumen"
                fi
                ;;
            *)
                description="Comando personalizado"
                ;;
        esac
        
        # Append to hotkeys file
        echo "$key_combo → $description" >> "$hotkeys_file"
    done
    
    echo -e "${GREEN}Lista de hotkeys generada en $hotkeys_file${NC}"
}

# Function to show hotkeys in rofi
show_hotkeys() {
    # Check if hotkeys file exists and is newer than config
    if [[ ! -f "$HOTKEYS_FILE" ]] || [[ "$CONFIG_FILE" -nt "$HOTKEYS_FILE" ]]; then
        generate_hotkeys "$CONFIG_FILE" "$HOTKEYS_FILE"
    fi
    
    # Show in rofi
    if [[ -f "$HOTKEYS_FILE" ]]; then
        rofi -dmenu -p "i3 Hotkeys" -i < "$HOTKEYS_FILE"
    else
        echo -e "${RED}No se pudo generar la lista de hotkeys${NC}"
        return 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "--generate")
            generate_hotkeys "$CONFIG_FILE" "$HOTKEYS_FILE"
            ;;
        *)
            show_hotkeys
            ;;
    esac
fi
