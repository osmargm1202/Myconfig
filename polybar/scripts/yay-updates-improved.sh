#!/bin/bash

# Script mejorado para actualizaciones de yay con mejor manejo de errores
# Si se ejecuta con argumento "update", ejecuta la actualización

if [ "$1" = "update" ]; then
    # Verificar que yay esté instalado
    if ! command -v yay &>/dev/null; then
        if command -v notify-send &>/dev/null; then
            notify-send "Error" "yay no está instalado" -u critical
        fi
        echo "Error: yay no está instalado"
        exit 1
    fi
    
    # Ejecutar actualización en terminal
    if command -v kitty &>/dev/null; then
        kitty --hold -e bash -c "
            echo 'Actualizando paquetes con yay...'
            echo 'Esto puede tomar varios minutos...'
            echo ''
            yay --noconfirm
            echo ''
            echo 'Actualización completada.'
            echo 'Presiona Enter para cerrar.'
            read
        "
    elif command -v alacritty &>/dev/null; then
        alacritty --hold -e bash -c "
            echo 'Actualizando paquetes con yay...'
            echo 'Esto puede tomar varios minutos...'
            echo ''
            yay --noconfirm
            echo ''
            echo 'Actualización completada.'
            echo 'Presiona Enter para cerrar.'
            read
        "
    elif command -v gnome-terminal &>/dev/null; then
        gnome-terminal -- bash -c "
            echo 'Actualizando paquetes con yay...'
            echo 'Esto puede tomar varios minutos...'
            echo ''
            yay --noconfirm
            echo ''
            echo 'Actualización completada.'
            echo 'Presiona Enter para cerrar.'
            read
        "
    else
        # Fallback: ejecutar en background y mostrar notificación
        yay --noconfirm &
        if command -v notify-send &>/dev/null; then
            notify-send "Yay Updates" "Actualización iniciada en segundo plano"
        fi
    fi
else
    # Mostrar número de paquetes disponibles para actualizar
    if ! command -v yay &>/dev/null; then
        echo "󰏕 ?"
        exit 0
    fi
    
    updates=$(yay -Qu 2>/dev/null | wc -l)
    if [ "$updates" -gt 0 ]; then
        echo "󰏕 $updates"
    else
        echo "󰏕 0"
    fi
fi
