#!/bin/bash

# Script Modo Juego para i3wm
# Togglea picom y polybar para optimizar recursos
# Uso: game-mode.sh [reload]

SCRIPT_NAME="Modo Juego"
PICOM_CONFIG="$HOME/.config/picom/picom.conf"
POLYBAR_CONFIG="$HOME/.config/polybar/config.ini"

# Función para mostrar notificaciones
notify() {
  if command -v notify-send &>/dev/null; then
    notify-send "$SCRIPT_NAME" "$1" -t 2000 -u normal
  fi
  echo "[$SCRIPT_NAME] $1"
}

# Función para verificar si un proceso está corriendo
is_running() {
  pgrep -x "$1" >/dev/null
}

# Función para iniciar picom
start_picom() {
  if [[ -f "$PICOM_CONFIG" ]]; then
    picom --config "$PICOM_CONFIG" -b &
    sleep 0.2
    if is_running picom; then
      echo "✅ Picom iniciado"
      return 0
    else
      echo "❌ Error al iniciar picom"
      return 1
    fi
  else
    picom -b &
    sleep 0.2
    if is_running picom; then
      echo "✅ Picom iniciado (config por defecto)"
      return 0
    else
      echo "❌ Error al iniciar picom"
      return 1
    fi
  fi
}

# Función para iniciar polybar
start_polybar() {
  if [[ -f "$POLYBAR_CONFIG" ]]; then
    polybar --config="$POLYBAR_CONFIG" modern &
    sleep 0.2
    if is_running polybar; then
      echo "✅ Polybar iniciado"
      return 0
    else
      echo "❌ Error al iniciar polybar"
      return 1
    fi
  else
    polybar &
    sleep 0.2
    if is_running polybar; then
      echo "✅ Polybar iniciado (config por defecto)"
      return 0
    else
      echo "❌ Error al iniciar polybar"
      return 1
    fi
  fi
}

# Función para detener procesos
stop_process() {
  local process_name="$1"
  if is_running "$process_name"; then
    killall -q "$process_name"
    sleep 0.2
    # Verificación de que se detuvo
    local count=0
    while is_running "$process_name" && [ $count -lt 3 ]; do
      sleep 0.2
      ((count++))
    done

    if ! is_running "$process_name"; then
      echo "🛑 $process_name detenido"
      return 0
    else
      echo "⚠️  $process_name no se pudo detener completamente"
      killall -9 "$process_name" 2>/dev/null
      return 1
    fi
  else
    echo "ℹ️  $process_name no estaba corriendo"
    return 0
  fi
}

# Función para optimizaciones adicionales del sistema
apply_game_optimizations() {
  echo "🎮 Aplicando optimizaciones para juegos..."

  # Desactivar compositor de escritorio adicionales
  if is_running compton; then
    stop_process compton
  fi

  # Cambiar governor de CPU a performance (si está disponible)
  if command -v cpupower &>/dev/null; then
    sudo cpupower frequency-set -g performance 2>/dev/null &&
      echo "⚡ CPU governor cambiado a performance"
  fi

  # Liberar caché del sistema
  sync && echo 1 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 &&
    echo "🧹 Caché del sistema liberado"

  # Desactivar actualizaciones automáticas temporalmente
  if systemctl is-active --quiet packagekit; then
    sudo systemctl stop packagekit 2>/dev/null &&
      echo "📦 Actualizaciones automáticas pausadas"
  fi
}

# Función para revertir optimizaciones
revert_game_optimizations() {
  echo "🔄 Revirtiendo optimizaciones..."

  # Restaurar governor de CPU a ondemand
  if command -v cpupower &>/dev/null; then
    sudo cpupower frequency-set -g ondemand 2>/dev/null &&
      echo "⚡ CPU governor restaurado a ondemand"
  fi

  # Reactivar actualizaciones automáticas
  if ! systemctl is-active --quiet packagekit; then
    sudo systemctl start packagekit 2>/dev/null &&
      echo "📦 Actualizaciones automáticas reactivadas"
  fi
}

# Función principal
main() {
  local arg="$1"
  local picom_running=$(is_running picom && echo "true" || echo "false")
  local polybar_running=$(is_running polybar && echo "true" || echo "false")

  echo "Estado actual:"
  echo "  Picom: $($picom_running && echo "🟢 Activo" || echo "🔴 Inactivo")"
  echo "  Polybar: $($polybar_running && echo "🟢 Activo" || echo "🔴 Inactivo")"
  echo ""

  case "$arg" in
  "reload")
    echo "🔄 Modo RELOAD: Reiniciando servicios..."
    stop_process picom
    stop_process polybar
    start_picom
    start_polybar
    notify "Servicios reiniciados 🔄"
    ;;
  *)
    # Lógica de toggle inteligente
    if [[ "$picom_running" == "true" && "$polybar_running" == "true" ]]; then
      # Ambos activos -> Activar modo juego (desactivar ambos)
      echo "🎮 ACTIVANDO MODO JUEGO..."
      stop_process picom
      stop_process polybar
      apply_game_optimizations
      notify "Modo Juego ACTIVADO 🎮\nRecursos optimizados"

    elif [[ "$picom_running" == "false" && "$polybar_running" == "false" ]]; then
      # Ambos inactivos -> Desactivar modo juego (activar ambos)
      echo "🖥️  DESACTIVANDO MODO JUEGO..."
      revert_game_optimizations
      start_picom
      start_polybar
      notify "Modo Juego DESACTIVADO 🖥️\nEscritorio restaurado"

    else
      # Estado mixto -> Normalizar (activar ambos)
      echo "⚖️  NORMALIZANDO ESTADO..."
      if [[ "$picom_running" == "false" ]]; then
        start_picom
      fi
      if [[ "$polybar_running" == "false" ]]; then
        start_polybar
      fi
      revert_game_optimizations
      notify "Estado normalizado ⚖️\nServicios sincronizados"
    fi
    ;;
  esac

  # Estado final
  echo ""
  echo "Estado final:"
  echo "  Picom: $(is_running picom && echo "🟢 Activo" || echo "🔴 Inactivo")"
  echo "  Polybar: $(is_running polybar && echo "🟢 Activo" || echo "🔴 Inactivo")"
}

# Verificar dependencias
check_dependencies() {
  local missing_deps=()

  if ! command -v picom &>/dev/null; then
    missing_deps+=("picom")
  fi

  if ! command -v polybar &>/dev/null; then
    missing_deps+=("polybar")
  fi

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo "❌ Dependencias faltantes: ${missing_deps[*]}"
    echo "Instala las dependencias faltantes antes de usar este script."
    exit 1
  fi
}

# Verificar dependencias y ejecutar
check_dependencies
main "$@"
