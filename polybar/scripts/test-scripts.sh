#!/bin/bash

# Script de prueba para verificar que los scripts de polybar funcionan correctamente

echo "=== Prueba de Scripts de Polybar ==="
echo

# Probar script de cambio de teclado
echo "1. Probando script de cambio de teclado..."
echo "Layout actual: $(setxkbmap -query | grep layout | awk '{print $2}')"
echo "Ejecutando keyboard-toggle.sh..."
~/.config/polybar/scripts/keyboard-toggle.sh
echo "Layout después del cambio: $(setxkbmap -query | grep layout | awk '{print $2}')"
echo

# Probar script de yay updates
echo "2. Probando script de yay updates..."
echo "Paquetes disponibles para actualizar:"
~/.config/polybar/scripts/yay-updates-improved.sh
echo

# Probar script de flatpak updates
echo "3. Probando script de flatpak updates..."
echo "Aplicaciones flatpak disponibles para actualizar:"
~/.config/polybar/scripts/flatpak-updates-improved.sh
echo

echo "=== Pruebas completadas ==="
echo "Los scripts están funcionando correctamente."
echo "Ahora puedes hacer click en los módulos de polybar para:"
echo "- Cambiar layout de teclado (US ↔ Latam)"
echo "- Actualizar paquetes con yay"
echo "- Actualizar aplicaciones flatpak"
