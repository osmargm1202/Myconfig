#!/bin/bash
#
# Power Menu for Polybar
# Usa rofi con el tema por defecto
#

# Opciones del menú de energía
shutdown=" Apagar"
reboot=" Reiniciar"
lock=" Bloquear"
suspend=" Suspender"
logout=" Cerrar Sesión"

# Mostrar menú con rofi usando el tema por defecto
chosen=$(printf '%s\n' "$shutdown" "$reboot" "$lock" "$suspend" "$logout" | rofi -dmenu -i -p "Opciones de Energía")

case $chosen in
    $shutdown)
        systemctl poweroff
        ;;
    $reboot)
        systemctl reboot
        ;;
    $lock)
        # Usar i3lock con blur
        if command -v i3lock &> /dev/null; then
            i3lock --blur 5
        else
            notify-send "Error" "i3lock no está instalado"
        fi
        ;;
    $suspend)
        systemctl suspend
        ;;
    $logout)
        i3-msg exit
        ;;
esac