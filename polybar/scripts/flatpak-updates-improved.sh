#!/bin/bash

# Script mejorado para actualizaciones de flatpak con mejor manejo de errores
# Si se ejecuta con argumento "update", ejecuta la actualización

if [ "$1" = "update" ]; then
    # Verificar que flatpak esté instalado
    if ! command -v flatpak &>/dev/null; then
        if command -v notify-send &>/dev/null; then
            notify-send "Error" "flatpak no está instalado" -u critical
        fi
        echo "Error: flatpak no está instalado"
        exit 1
    fi
    
    # Ejecutar actualización en terminal
    if command -v kitty &>/dev/null; then
        kitty --hold -e bash -c "
            echo 'Actualizando aplicaciones Flatpak...'
            echo 'Esto puede tomar varios minutos...'
            echo ''
            flatpak update -y
            echo ''
            echo 'Actualización completada.'
            echo 'Presiona Enter para cerrar.'
            read
        "
    elif command -v alacritty &>/dev/null; then
        alacritty --hold -e bash -c "
            echo 'Actualizando aplicaciones Flatpak...'
            echo 'Esto puede tomar varios minutos...'
            echo ''
            flatpak update -y
            echo ''
            echo 'Actualización completada.'
            echo 'Presiona Enter para cerrar.'
            read
        "
    elif command -v gnome-terminal &>/dev/null; then
        gnome-terminal -- bash -c "
            echo 'Actualizando aplicaciones Flatpak...'
            echo 'Esto puede tomar varios minutos...'
            echo ''
            flatpak update -y
            echo ''
            echo 'Actualización completada.'
            echo 'Presiona Enter para cerrar.'
            read
        "
    else
        # Fallback: ejecutar en background y mostrar notificación
        flatpak update -y &
        if command -v notify-send &>/dev/null; then
            notify-send "Flatpak Updates" "Actualización iniciada en segundo plano"
        fi
    fi
else
    # Mostrar número de paquetes flatpak disponibles para actualizar
    if ! command -v flatpak &>/dev/null; then
        echo "󰏖 ?"
        exit 0
    fi
    
    updates=$(flatpak list --updates 2>/dev/null | wc -l)
    if [ "$updates" -gt 0 ]; then
        echo "󰏖 $updates"
    else
        echo "󰏖 0"
    fi
fi
