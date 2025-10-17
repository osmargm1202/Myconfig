#!/bin/bash

# Script de instalación de impresoras para Arch Linux
# Instala CUPS, drivers de impresora Epson y configuración del sistema

set -e

echo "🖨️  Instalando sistema de impresoras..."

# Instalar CUPS y cups-pdf
echo "📦 Instalando CUPS y cups-pdf..."
sudo pacman -S cups cups-pdf --noconfirm

# Instalar driver de impresora Epson desde AUR
echo "📦 Instalando driver de impresora Epson..."
yay -S epson-inkjet-printer-escpr --noconfirm

# Habilitar y iniciar el servicio CUPS
echo "🔧 Configurando servicio CUPS..."
sudo systemctl enable cups.service
sudo systemctl start cups.service

# Agregar usuario al grupo lp
echo "👤 Agregando usuario al grupo lp..."
sudo usermod -aG lp $USER

# Instalar system-config-printer
echo "📦 Instalando system-config-printer..."
sudo pacman -S system-config-printer --noconfirm

echo "📦 Instalando EPSON 3250..."
yay -S epson-laser-printer-lp-s3250 --noconfirm

echo "✅ Instalación completada!"
echo "🔄 Reinicia tu sesión para que los cambios de grupo tengan efecto."
echo "🖨️  Puedes acceder a la configuración de impresoras desde el menú de aplicaciones."
