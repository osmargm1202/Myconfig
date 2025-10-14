#!/bin/bash

# Script para mostrar paquetes disponibles para actualizar con yay
# Si se ejecuta con argumento "update", ejecuta la actualización

if [ "$1" = "update" ]; then
    # Ejecutar actualización
    yay --noconfirm
else
    # Mostrar número de paquetes disponibles para actualizar
    updates=$(yay -Qu 2>/dev/null | wc -l)
    if [ "$updates" -gt 0 ]; then
        echo "󰏕 $updates"
    else
        echo "󰏕 0"
    fi
fi
