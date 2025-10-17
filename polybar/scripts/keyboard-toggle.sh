#!/bin/bash

# Script para cambiar entre layouts de teclado US y Latam
# Alterna entre los layouts configurados en el sistema

# Obtener el layout actual
current_layout=$(setxkbmap -query | grep layout | awk '{print $2}')

# Determinar el siguiente layout
if [[ "$current_layout" == "us" ]]; then
    next_layout="latam"
else
    next_layout="us"
fi

# Cambiar al siguiente layout
setxkbmap "$next_layout"

# Verificar que el cambio fue exitoso
if [[ $? -eq 0 ]]; then
    # Mostrar notificación (si está disponible)
    if command -v notify-send &>/dev/null; then
        notify-send "Teclado" "Layout cambiado a: $next_layout" -t 2000
    fi
    
    # También mostrar en terminal si se ejecuta desde ahí
    echo "Layout cambiado a: $next_layout"
else
    # Si falla, intentar con el layout completo
    if [[ "$current_layout" == "us" ]]; then
        setxkbmap "us,latam"
    else
        setxkbmap "latam,us"
    fi
    
    if command -v notify-send &>/dev/null; then
        notify-send "Teclado" "Layout alternado (us,latam)" -t 2000
    fi
    echo "Layout alternado (us,latam)"
fi
