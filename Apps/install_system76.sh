#!/usr/bin/env bash

# Script to install System76 Power Management Tools
# This script installs system76-power daemon and GUI

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display header
show_header() {
  clear
  echo "========================================"
  echo "   System76 Power Management Installer  "
  echo "========================================"
  echo
}

# Function to check if package is installed
is_installed() {
  pacman -Q "$1" &>/dev/null
}

# Main installation function
install_system76_power() {
  show_header
  
  echo -e "${BLUE}Este script instalará:${NC}"
  echo -e "${WHITE}  • system76-power (daemon de gestión de energía)${NC}"
  echo -e "${WHITE}  • system76-power-gui-x11 (interfaz gráfica)${NC}"
  echo
  echo -e "${YELLOW}¿Continuar con la instalación? (y/N):${NC} "
  read -r confirm </dev/tty
  
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Instalación cancelada${NC}"
    exit 0
  fi
  
  echo
  echo -e "${GREEN}Iniciando instalación...${NC}"
  echo
  
  # Check if yay or paru is installed
  if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
    echo -e "${RED}✗ No se encontró ningún AUR helper (yay/paru)${NC}"
    echo -e "${YELLOW}Por favor instala yay o paru primero${NC}"
    exit 1
  fi
  
  # Determine which AUR helper to use
  if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
  else
    AUR_HELPER="paru"
  fi
  
  echo -e "${BLUE}Usando AUR helper: $AUR_HELPER${NC}"
  echo
  
  # Install system76-power
  if is_installed "system76-power"; then
    echo -e "${GREEN}✓ system76-power ya está instalado${NC}"
  else
    echo -e "${BLUE}Instalando system76-power...${NC}"
    if $AUR_HELPER -S system76-power --noconfirm; then
      echo -e "${GREEN}✓ system76-power instalado exitosamente${NC}"
    else
      echo -e "${RED}✗ Error al instalar system76-power${NC}"
      exit 1
    fi
  fi
  
  # Install system76-power-gui-x11
  if is_installed "system76-power-gui-x11"; then
    echo -e "${GREEN}✓ system76-power-gui-x11 ya está instalado${NC}"
  else
    echo -e "${BLUE}Instalando system76-power-gui-x11...${NC}"
    if $AUR_HELPER -S system76-power-gui-x11 --noconfirm; then
      echo -e "${GREEN}✓ system76-power-gui-x11 instalado exitosamente${NC}"
    else
      echo -e "${RED}✗ Error al instalar system76-power-gui-x11${NC}"
      exit 1
    fi
  fi
  
  echo
  echo -e "${BLUE}Habilitando servicio system76-power...${NC}"
  
  # Enable and start the service
  if sudo systemctl enable system76-power.service; then
    echo -e "${GREEN}✓ Servicio habilitado${NC}"
  else
    echo -e "${RED}✗ Error al habilitar el servicio${NC}"
  fi
  
  if sudo systemctl start system76-power.service; then
    echo -e "${GREEN}✓ Servicio iniciado${NC}"
  else
    echo -e "${YELLOW}⚠ El servicio se iniciará en el próximo reinicio${NC}"
  fi
  
  echo
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}✓ Instalación completada exitosamente!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo
  echo -e "${BLUE}Notas importantes:${NC}"
  echo -e "${WHITE}  • El daemon system76-power está ahora activo${NC}"
  echo -e "${WHITE}  • Puedes abrir la GUI con: system76-power-gui-x11${NC}"
  echo -e "${WHITE}  • El icono de batería en polybar abrirá la GUI al hacer click${NC}"
  echo -e "${WHITE}  • Reinicia tu sesión de i3 para aplicar todos los cambios${NC}"
  echo
}

# Run installation
install_system76_power

# Wait for user input before returning to menu
echo
read -p "Presiona Enter para volver al menú principal..." </dev/tty
