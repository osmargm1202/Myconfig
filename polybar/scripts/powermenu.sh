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
        # Verifica si i3lock-color está disponible, si no usa i3lock normal
        if command -v i3lock-color &> /dev/null; then
            ~/.config/i3/scripts/lock.sh
        elif command -v i3lock &> /dev/null; then
            i3lock -c 1a1b26
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