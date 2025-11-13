#!/bin/bash
#
# Script para configurar lock automático al apagar pantalla
# Configura DPMS y xss-lock para bloquear cuando se apague la pantalla
#

# Configurar tiempo de inactividad antes de apagar pantalla
# xset s <tiempo_standby> <tiempo_suspend> <tiempo_off>
# Tiempos en segundos:
# - 300 = 5 minutos para standby
# - 600 = 10 minutos para suspend
# - 900 = 15 minutos para off
xset s 300 5
xset dpms 300 600 900

# xss-lock se activará cuando:
# - Se suspenda el sistema
# - Se apague la pantalla (DPMS)
# - Se ejecute loginctl lock-session
# --transfer-sleep-lock: transfiere el lock de sleep a xss-lock
# --notifier: comando a ejecutar cuando se detecte que la pantalla se apagará
xss-lock --transfer-sleep-lock --notifier="xset dpms force off" -- ~/.config/i3/scripts/lock.sh

