#!/bin/bash

# Script para mostrar paquetes flatpak disponibles para actualizar
# Si se ejecuta con argumento "update", ejecuta la actualización

if [ "$1" = "update" ]; then
    # Ejecutar actualización
    flatpak update -y
else
    # Mostrar número de paquetes flatpak disponibles para actualizar
    updates=$(flatpak list --updates 2>/dev/null | wc -l)
    if [ "$updates" -gt 0 ]; then
        echo "󰏖 $updates"
    else
        echo "󰏖 0"
    fi
fi
