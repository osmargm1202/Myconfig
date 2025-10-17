#!/bin/bash

# Script para mostrar paquetes flatpak disponibles para actualizar
# Si se ejecuta con argumento "update", ejecuta la actualización

if [ "$1" = "update" ]; then
    # Ejecutar actualización en terminal
    if command -v kitty &>/dev/null; then
        kitty --hold -e bash -c "echo 'Actualizando aplicaciones Flatpak...'; flatpak update -y; echo 'Actualización completada. Presiona Enter para cerrar.'; read"
    elif command -v alacritty &>/dev/null; then
        alacritty --hold -e bash -c "echo 'Actualizando aplicaciones Flatpak...'; flatpak update -y; echo 'Actualización completada. Presiona Enter para cerrar.'; read"
    elif command -v gnome-terminal &>/dev/null; then
        gnome-terminal -- bash -c "echo 'Actualizando aplicaciones Flatpak...'; flatpak update -y; echo 'Actualización completada. Presiona Enter para cerrar.'; read"
    else
        # Fallback: ejecutar en background y mostrar notificación
        flatpak update -y &
        if command -v notify-send &>/dev/null; then
            notify-send "Flatpak Updates" "Actualización iniciada en segundo plano"
        fi
    fi
else
    # Mostrar número de paquetes flatpak disponibles para actualizar
    updates=$(flatpak list --updates 2>/dev/null | wc -l)
    if [ "$updates" -gt 0 ]; then
        echo "󰏖 $updates"
    else
        echo "󰏖 0"
    fi
fi
