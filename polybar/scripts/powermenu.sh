#!/bin/bash
#
# Power Menu for Polybar
# Uses rofi for the menu interface with system default theme
#

# Power menu options
shutdown=" Apagar"
reboot=" Reiniciar"
lock=" Bloquear"
suspend=" Suspender"
logout=" Cerrar Sesión"

# Show menu with default or DarkBlue theme
chosen=$(printf '%s\n' "$shutdown" "$reboot" "$lock" "$suspend" "$logout" | rofi -dmenu -i -p "Opciones de Energía" -theme DarkBlue 2>/dev/null || \
         printf '%s\n' "$shutdown" "$reboot" "$lock" "$suspend" "$logout" | rofi -dmenu -i -p "Opciones de Energía")

case $chosen in
    $shutdown)
        systemctl poweroff
        ;;
    $reboot)
        systemctl reboot
        ;;
    $lock)
        # Check if i3lock-color is available, fallback to regular i3lock
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