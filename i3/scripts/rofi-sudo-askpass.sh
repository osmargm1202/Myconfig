#!/usr/bin/env bash
#
# Rofi Sudo Askpass Helper
# Usado para pedir contraseña con rofi cuando se necesita sudo
#

# Pedir contraseña con rofi
# -password oculta el texto ingresado
# -p establece el prompt
rofi -dmenu -password -p "Contraseña sudo:" -lines 0 -theme-str 'entry { placeholder: "Ingresa tu contraseña"; }' 2>/dev/null

