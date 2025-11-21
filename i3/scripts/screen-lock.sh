#!/bin/bash
#
# Script para configurar lock automático al apagar pantalla
# Respeta el modo cafeína: si está activado, no configura timeouts ni xss-lock
#

CAFFEINE_SCRIPT="$HOME/.config/i3/scripts/caffeine.sh"
STATE_FILE="$HOME/.config/i3/caffeine_state"

# Función para leer el estado del modo cafeína
get_caffeine_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "enabled"  # Default: activado
    fi
}

# Aplicar configuración según el estado del modo cafeína
caffeine_state=$(get_caffeine_state)

echo "[DEBUG] Estado modo cafeína: $caffeine_state" >&2

if [[ "$caffeine_state" == "enabled" ]]; then
    echo "[DEBUG] Modo cafeína activado - desactivando timeouts automáticos" >&2
    
    # Desactivar DPMS y screen saver
    xset -dpms 2>/dev/null
    xset s off 2>/dev/null
    
    # Asegurarse de que xss-lock y xautolock no estén corriendo
    pkill -x xss-lock 2>/dev/null
    pkill -x xautolock 2>/dev/null
else
    echo "[DEBUG] Modo cafeína desactivado - configurando timeouts automáticos" >&2
    
    # Activar DPMS
    xset +dpms 2>/dev/null
    
    # Configurar tiempo de inactividad antes de apagar pantalla
    # xset s <tiempo_standby> <tiempo_suspend> <tiempo_off>
    # Tiempos en segundos:
    # - 300 = 5 minutos para standby
    # - 600 = 10 minutos para screen off
    # - 1800 = 30 minutos para suspend
    xset s 300 5 2>/dev/null
    xset dpms 600 1200 1800 2>/dev/null
    
    # Iniciar xautolock para lock a los 5 minutos (300 segundos)
    if ! pgrep -x xautolock > /dev/null; then
        echo "[DEBUG] Iniciando xautolock para lock a los 5 minutos..." >&2
        xautolock -time 5 -locker "i3lock --blur 5" -detectsleep &
    fi
    
    # xss-lock se activará cuando:
    # - Se suspenda el sistema
    # - Se apague la pantalla (DPMS)
    # - Se ejecute loginctl lock-session
    # --transfer-sleep-lock: transfiere el lock de sleep a xss-lock
    # --notifier: comando a ejecutar cuando se detecte que la pantalla se apagará
    if ! pgrep -x xss-lock > /dev/null; then
        echo "[DEBUG] Iniciando xss-lock..." >&2
        xss-lock --transfer-sleep-lock --notifier="xset dpms force off" -- i3lock --blur 5 &
    fi
fi
