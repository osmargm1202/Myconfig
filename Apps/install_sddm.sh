#!/usr/bin/env bash

# SDDM Theme Corners Installer
# Installs and configures SDDM with corners theme

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to display header
show_header() {
  clear
  echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║         SDDM Theme Installer          ║${NC}"
  echo -e "${CYAN}║       Corners Theme + Config          ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
  echo
}

# Function to check if running as root
check_root() {
  if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}✗ Este script no debe ejecutarse como root${NC}"
    echo -e "${BLUE}Ejecuta como usuario normal, se pedirán permisos sudo cuando sea necesario${NC}"
    exit 1
  fi
}

# Function to install SDDM and theme
install_sddm_theme() {
  echo -e "${BLUE}Instalando SDDM y theme corners...${NC}"
  
  # Check if AUR helper is available
  local aur_helper=""
  if command -v yay &>/dev/null; then
    aur_helper="yay"
  elif command -v paru &>/dev/null; then
    aur_helper="paru"
  else
    echo -e "${RED}✗ No se encontró un AUR helper (yay o paru)${NC}"
    echo -e "${YELLOW}Instala un AUR helper primero${NC}"
    return 1
  fi
  
  # Install SDDM
  echo -e "${BLUE}Instalando SDDM...${NC}"
  if sudo pacman -S sddm --noconfirm; then
    echo -e "${GREEN}✓ SDDM instalado${NC}"
  else
    echo -e "${RED}✗ Error al instalar SDDM${NC}"
    return 1
  fi
  
  # Install corners theme
  echo -e "${BLUE}Instalando theme corners desde AUR...${NC}"
  if $aur_helper -S sddm-theme-corners-git --noconfirm; then
    echo -e "${GREEN}✓ Theme corners instalado${NC}"
  else
    echo -e "${RED}✗ Error al instalar theme corners${NC}"
    return 1
  fi
  
  return 0
}

# Function to configure SDDM
configure_sddm() {
  echo -e "${BLUE}Configurando SDDM...${NC}"
  
  local sddm_conf="/etc/sddm.conf"
  local backup_conf="/etc/sddm.conf.backup.$(date +%Y%m%d_%H%M%S)"
  
  # Create backup of existing config
  if [[ -f "$sddm_conf" ]]; then
    echo -e "${YELLOW}Creando backup de configuración existente...${NC}"
    sudo cp "$sddm_conf" "$backup_conf"
    echo -e "${GREEN}✓ Backup creado: $backup_conf${NC}"
  fi
  
  # Ask about autologin
  echo
  echo -e "${YELLOW}¿Deseas activar autologin (inicio automático sin contraseña)? (y/N):${NC} "
  read -r enable_autologin </dev/tty
  
  local autologin_user=""
  if [[ "$enable_autologin" =~ ^[Yy]$ ]]; then
    autologin_user="$USER"
    echo -e "${GREEN}Autologin activado para usuario: $autologin_user${NC}"
  else
    echo -e "${BLUE}Autologin desactivado${NC}"
  fi
  
  # Create SDDM configuration
  echo -e "${BLUE}Creando configuración SDDM...${NC}"
  
  sudo tee "$sddm_conf" > /dev/null << EOF
[Autologin]
Relogin=false
Session=
User=$autologin_user

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Theme]
Current=corners

[Users]
MaximumUid=60513
MinimumUid=1000

[X11]
MinimumVT=1
ServerPath=/usr/bin/X
XephyrPath=/usr/bin/Xephyr
SessionCommand=/usr/share/sddm/scripts/Xsession
SessionDir=/usr/share/xsessions
XauthPath=/usr/bin/xauth
XDisplayStop=30
XDisplayStart=0
EOF

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Configuración SDDM creada${NC}"
  else
    echo -e "${RED}✗ Error al crear configuración SDDM${NC}"
    return 1
  fi
  
  return 0
}

# Function to enable SDDM service
enable_sddm_service() {
  echo -e "${BLUE}Habilitando servicio SDDM...${NC}"
  
  # Disable other display managers first
  echo -e "${YELLOW}Deshabilitando otros display managers...${NC}"
  sudo systemctl disable gdm lightdm lxdm 2>/dev/null || true
  
  # Enable SDDM
  if sudo systemctl enable sddm; then
    echo -e "${GREEN}✓ Servicio SDDM habilitado${NC}"
  else
    echo -e "${RED}✗ Error al habilitar servicio SDDM${NC}"
    return 1
  fi
  
  return 0
}

# Function to show completion message
show_completion() {
  echo
  echo -e "${GREEN}✓ ¡SDDM con theme corners instalado y configurado!${NC}"
  echo
  echo -e "${WHITE}Configuración aplicada:${NC}"
  echo -e "${BLUE}  • Theme: corners${NC}"
  if [[ -n "$1" ]]; then
    echo -e "${BLUE}  • Autologin: activado para $1${NC}"
  else
    echo -e "${BLUE}  • Autologin: desactivado${NC}"
  fi
  echo
  echo -e "${YELLOW}Nota: Reinicia tu sistema para que los cambios tomen efecto${NC}"
  echo -e "${BLUE}El nuevo login manager se activará en el próximo inicio${NC}"
  echo
}

# Main execution
main() {
  show_header
  check_root
  
  echo -e "${WHITE}Este script instalará:${NC}"
  echo -e "${BLUE}  1. SDDM (Simple Desktop Display Manager)${NC}"
  echo -e "${BLUE}  2. Theme corners desde AUR${NC}"
  echo -e "${BLUE}  3. Configuración automática${NC}"
  echo -e "${BLUE}  4. Opción de autologin${NC}"
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
  
  # Install SDDM and theme
  if ! install_sddm_theme; then
    echo -e "${RED}✗ Error en la instalación${NC}"
    exit 1
  fi
  
  echo
  
  # Configure SDDM
  if ! configure_sddm; then
    echo -e "${RED}✗ Error en la configuración${NC}"
    exit 1
  fi
  
  echo
  
  # Enable service
  if ! enable_sddm_service; then
    echo -e "${RED}✗ Error al habilitar servicio${NC}"
    exit 1
  fi
  
  # Show completion
  local autologin_status=""
  if [[ "$enable_autologin" =~ ^[Yy]$ ]]; then
    autologin_status="$USER"
  fi
  show_completion "$autologin_status"
}

# Run main function
main "$@"
