#!/bin/bash
#
# Script para manejar el modo cafeína
# Previene que la pantalla se apague, se bloquee o se suspenda automáticamente
#

STATE_FILE="$HOME/.config/i3/caffeine_state"
LOCK_SCRIPT="$HOME/.config/i3/scripts/screen-lock.sh"

# Función para leer el estado
get_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "enabled"  # Default: activado
    fi
}

# Función para escribir el estado
set_state() {
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "$1" > "$STATE_FILE"
    echo "[DEBUG] Estado cafeína guardado: $1" >&2
}

# Función para activar modo cafeína
enable_caffeine() {
    echo "[DEBUG] Activando modo cafeína..." >&2
    
    # Desactivar DPMS y screen saver
    xset -dpms 2>/dev/null
    xset s off 2>/dev/null
    
    # Matar xss-lock y xautolock si están corriendo
    pkill -x xss-lock 2>/dev/null
    pkill -x xautolock 2>/dev/null
    
    # Guardar estado
    set_state "enabled"
    
    # Notificar a polybar
    polybar-msg hook caffeine 1 2>/dev/null || true
    
    notify-send -u low -a "Cafeína" "Modo cafeína activado" "La pantalla no se apagará automáticamente" 2>/dev/null || true
}

# Función para desactivar modo cafeína
disable_caffeine() {
    echo "[DEBUG] Desactivando modo cafeína..." >&2
    
    # Activar DPMS
    xset +dpms 2>/dev/null
    
    # Configurar timeouts:
    # - Screen saver: 5 minutos (300 segundos)
    # - DPMS: 10 minutos screen off (600), 20 minutos suspend (1200), 30 minutos off (1800)
    xset s 300 5 2>/dev/null
    xset dpms 600 1200 1800 2>/dev/null
    
    # Iniciar xautolock para lock a los 5 minutos (300 segundos)
    if ! pgrep -x xautolock > /dev/null; then
        echo "[DEBUG] Iniciando xautolock para lock a los 5 minutos..." >&2
        xautolock -time 5 -locker "i3lock --blur 5" -detectsleep &
    fi
    
    # Iniciar xss-lock para lock cuando se apague la pantalla o se suspenda
    if ! pgrep -x xss-lock > /dev/null; then
        echo "[DEBUG] Iniciando xss-lock..." >&2
        xss-lock --transfer-sleep-lock --notifier="xset dpms force off" -- i3lock --blur 5 &
    fi
    
    # Guardar estado
    set_state "disabled"
    
    # Notificar a polybar
    polybar-msg hook caffeine 1 2>/dev/null || true
    
    notify-send -u low -a "Cafeína" "Modo cafeína desactivado" "La pantalla se apagará después de 10 minutos de inactividad" 2>/dev/null || true
}

# Función para toggle
toggle_caffeine() {
    current_state=$(get_state)
    if [[ "$current_state" == "enabled" ]]; then
        disable_caffeine
    else
        enable_caffeine
    fi
}

# Función para aplicar el estado actual (usado al inicio)
apply_state() {
    current_state=$(get_state)
    if [[ "$current_state" == "enabled" ]]; then
        enable_caffeine
    else
        disable_caffeine
    fi
}

# Main
case "${1:-}" in
    toggle)
        toggle_caffeine
        ;;
    enable)
        enable_caffeine
        ;;
    disable)
        disable_caffeine
        ;;
    status)
        get_state
        ;;
    apply)
        apply_state
        ;;
    *)
        echo "Uso: $0 {toggle|enable|disable|status|apply}"
        exit 1
        ;;
esac

