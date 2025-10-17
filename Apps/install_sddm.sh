#!/usr/bin/env bash

# SDDM Theme Corners Installer
# Installs and configures SDDM with corners theme

# Support for non-interactive mode
FORCE_YES=false
ENABLE_AUTOLOGIN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes|--force)
      FORCE_YES=true
      shift
      ;;
    --autologin)
      ENABLE_AUTOLOGIN=true
      shift
      ;;
    -h|--help)
      echo "Uso: $0 [opciones]"
      echo "Opciones:"
      echo "  -y, --yes, --force    Instalar sin confirmaciones"
      echo "  --autologin          Activar autologin automáticamente"
      echo "  -h, --help           Mostrar esta ayuda"
      exit 0
      ;;
    *)
      echo "Opción desconocida: $1"
      echo "Usa $0 --help para ver las opciones disponibles"
      exit 1
      ;;
  esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Check if Gum is available and set colors
HAS_GUM=false
if command -v gum &>/dev/null; then
  HAS_GUM=true
  # Gum color configuration
  export GUM_CHOOSE_SELECTED_FOREGROUND="#87CEEB"  # Sky Blue
  export GUM_CHOOSE_CURSOR_FOREGROUND="#00BFFF"    # Deep Sky Blue
  export GUM_CONFIRM_SELECTED_FOREGROUND="#87CEEB"
  export GUM_INPUT_CURSOR_FOREGROUND="#00BFFF"
  export GUM_INPUT_PROMPT_FOREGROUND="#87CEEB"
fi

# Function to ask for confirmation with Gum support
ask_confirmation() {
  local message="$1"
  
  # If force mode is enabled, always return true
  if [[ "$FORCE_YES" == true ]]; then
    echo -e "${GREEN}✓ $message (forzado con -y)${NC}"
    return 0
  fi
  
  if [[ "$HAS_GUM" == true ]] && [[ -c /dev/tty ]]; then
    gum confirm "$message" < /dev/tty
    return $?
  else
    # Fallback to traditional prompt
    echo -e "${YELLOW}$message (y/N):${NC} "
    read -r response </dev/tty
    [[ "$response" =~ ^[Yy]$ ]]
    return $?
  fi
}

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
  local enable_autologin="n"
  
  if [[ "$ENABLE_AUTOLOGIN" == true ]]; then
    enable_autologin="y"
    echo -e "${GREEN}✓ Autologin activado automáticamente (parámetro --autologin)${NC}"
  elif ask_confirmation "¿Deseas activar autologin (inicio automático sin contraseña)?"; then
    enable_autologin="y"
  fi
  
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
  local other_dms=(gdm gdm3 lightdm lxdm xdm kdm nodm slim entrance)
  
  for dm in "${other_dms[@]}"; do
    if systemctl is-enabled "$dm" &>/dev/null; then
      echo -e "${YELLOW}  • Deshabilitando $dm...${NC}"
      sudo systemctl disable "$dm" 2>/dev/null || true
    fi
  done
  
  # Stop any running display managers
  echo -e "${YELLOW}Deteniendo display managers en ejecución...${NC}"
  for dm in "${other_dms[@]}"; do
    if systemctl is-active "$dm" &>/dev/null; then
      echo -e "${YELLOW}  • Deteniendo $dm...${NC}"
      sudo systemctl stop "$dm" 2>/dev/null || true
    fi
  done
  
  # Enable SDDM
  echo -e "${BLUE}Habilitando SDDM...${NC}"
  if sudo systemctl enable sddm; then
    echo -e "${GREEN}✓ Servicio SDDM habilitado${NC}"
  else
    echo -e "${RED}✗ Error al habilitar servicio SDDM${NC}"
    return 1
  fi
  
  return 0
}

# Function to validate SDDM is default display manager
validate_sddm_default() {
  echo -e "${BLUE}Validando configuración de SDDM...${NC}"
  
  local validation_failed=false
  
  # Check if SDDM is enabled
  if systemctl is-enabled sddm &>/dev/null; then
    echo -e "${GREEN}✓ SDDM está habilitado${NC}"
  else
    echo -e "${RED}✗ SDDM no está habilitado${NC}"
    validation_failed=true
  fi
  
  # Check for conflicting display managers
  local other_dms=(gdm gdm3 lightdm lxdm xdm kdm nodm slim entrance)
  local conflicts_found=false
  
  for dm in "${other_dms[@]}"; do
    if systemctl is-enabled "$dm" &>/dev/null; then
      echo -e "${RED}✗ Display manager en conflicto encontrado: $dm está habilitado${NC}"
      conflicts_found=true
      validation_failed=true
    fi
  done
  
  if [[ "$conflicts_found" == false ]]; then
    echo -e "${GREEN}✓ No se encontraron display managers en conflicto${NC}"
  fi
  
  # Check SDDM configuration file
  if [[ -f "/etc/sddm.conf" ]]; then
    echo -e "${GREEN}✓ Archivo de configuración SDDM existe${NC}"
    
    # Check if corners theme is configured
    if grep -q "Current=corners" "/etc/sddm.conf"; then
      echo -e "${GREEN}✓ Theme corners configurado${NC}"
    else
      echo -e "${YELLOW}⚠ Theme corners no encontrado en configuración${NC}"
    fi
  else
    echo -e "${RED}✗ Archivo de configuración SDDM no encontrado${NC}"
    validation_failed=true
  fi
  
  # Check if corners theme is installed
  if [[ -d "/usr/share/sddm/themes/corners" ]]; then
    echo -e "${GREEN}✓ Theme corners instalado${NC}"
  else
    echo -e "${RED}✗ Theme corners no encontrado${NC}"
    validation_failed=true
  fi
  
  # Final validation
  if [[ "$validation_failed" == true ]]; then
    echo -e "${RED}✗ Validación fallida: SDDM no está configurado correctamente${NC}"
    return 1
  else
    echo -e "${GREEN}✓ SDDM está configurado correctamente como display manager por defecto${NC}"
    return 0
  fi
}

# Function to show completion message
show_completion() {
  echo
  echo -e "${GREEN}✓ ¡SDDM con theme corners instalado y configurado!${NC}"
  echo
  echo -e "${WHITE}Configuración aplicada:${NC}"
  echo -e "${BLUE}  • Display Manager: SDDM${NC}"
  echo -e "${BLUE}  • Theme: corners${NC}"
  echo -e "${BLUE}  • Estado: Validado como display manager por defecto${NC}"
  if [[ -n "$1" ]]; then
    echo -e "${BLUE}  • Autologin: activado para $1${NC}"
  else
    echo -e "${BLUE}  • Autologin: desactivado${NC}"
  fi
  echo
  echo -e "${WHITE}Comandos disponibles para uso futuro:${NC}"
  echo -e "${CYAN}  • Instalación automática: $0 -y${NC}"
  echo -e "${CYAN}  • Con autologin: $0 -y --autologin${NC}"
  echo -e "${CYAN}  • Ver ayuda: $0 --help${NC}"
  echo
  echo -e "${YELLOW}Nota: Reinicia tu sistema para que los cambios tomen efecto${NC}"
  echo -e "${BLUE}El nuevo login manager se activará en el próximo inicio${NC}"
  echo -e "${GREEN}Todos los display managers conflictivos han sido deshabilitados${NC}"
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
  echo -e "${BLUE}  4. Deshabilitación de otros display managers${NC}"
  echo -e "${BLUE}  5. Validación como display manager por defecto${NC}"
  echo -e "${BLUE}  6. Opción de autologin${NC}"
  echo
  
  # Force mode by default when called from setup.sh
  FORCE_YES=true
  
  if [[ "$FORCE_YES" == true ]]; then
    echo -e "${GREEN}✓ Modo automático activado (sin confirmaciones)${NC}"
  fi
  
  if [[ "$ENABLE_AUTOLOGIN" == true ]]; then
    echo -e "${GREEN}✓ Autologin se activará automáticamente${NC}"
  fi
  
  echo
  echo -e "${GREEN}Iniciando instalación automática...${NC}"
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
  
  echo
  
  # Validate SDDM configuration
  if ! validate_sddm_default; then
    echo -e "${RED}✗ Error en la validación final${NC}"
    echo -e "${YELLOW}⚠ SDDM puede no estar configurado correctamente como display manager por defecto${NC}"
    echo -e "${BLUE}Revisa manualmente la configuración si experimentas problemas${NC}"
    exit 1
  fi
  
  # Show completion
  local autologin_status=""
  if [[ "$ENABLE_AUTOLOGIN" == true ]] || [[ "$enable_autologin" =~ ^[Yy]$ ]]; then
    autologin_status="$USER"
  fi
  show_completion "$autologin_status"
}

# Run main function
main "$@"

# Wait for user input before returning to menu
echo
if [[ -c /dev/tty ]]; then
  read -p "Presiona Enter para volver al menú principal..." </dev/tty
else
  read -p "Presiona Enter para volver al menú principal..."
fi
