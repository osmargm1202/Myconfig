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
  # Check if AUR helper is available
  local aur_helper=""
  if command -v yay &>/dev/null; then
    aur_helper="yay"
  elif command -v paru &>/dev/null; then
    aur_helper="paru"
  else
    echo -e "${RED}✗ No se encontró un AUR helper${NC}"
    return 1
  fi
  
  # Install SDDM
  sudo pacman -S sddm --noconfirm
  
  # Install corners theme
  $aur_helper -S sddm-theme-corners-git --noconfirm
}

# Function to configure SDDM
configure_sddm() {
  local sddm_conf="/etc/sddm.conf"
  local backup_conf="/etc/sddm.conf.backup.$(date +%Y%m%d_%H%M%S)"
  
  # Create backup of existing config
  if [[ -f "$sddm_conf" ]]; then
    sudo cp "$sddm_conf" "$backup_conf"
  fi
  
  # Ask about autologin
  local enable_autologin="n"
  
  if [[ "$ENABLE_AUTOLOGIN" == true ]]; then
    enable_autologin="y"
  elif [[ "$HAS_GUM" == true ]]; then
    if gum confirm "¿Activar autologin (inicio automático sin contraseña)?"; then
      enable_autologin="y"
    fi
  fi
  
  local autologin_user=""
  if [[ "$enable_autologin" =~ ^[Yy]$ ]]; then
    autologin_user="$USER"
  fi
  
  # Create SDDM configuration
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
}

# Function to enable SDDM service
enable_sddm_service() {
  # Disable other display managers first
  local other_dms=(gdm gdm3 lightdm lxdm xdm kdm nodm slim entrance)
  
  for dm in "${other_dms[@]}"; do
    if systemctl is-enabled "$dm" &>/dev/null; then
      sudo systemctl disable "$dm" 2>/dev/null || true
    fi
  done
  
  # Stop any running display managers
  for dm in "${other_dms[@]}"; do
    if systemctl is-active "$dm" &>/dev/null; then
      sudo systemctl stop "$dm" 2>/dev/null || true
    fi
  done
  
  # Enable SDDM
  sudo systemctl enable sddm
}

# Function to validate SDDM is default display manager
validate_sddm_default() {
  # Check if SDDM is enabled
  if ! systemctl is-enabled sddm &>/dev/null; then
    echo -e "${RED}✗ SDDM no está habilitado${NC}"
    return 1
  fi
  
  # Check for conflicting display managers
  local other_dms=(gdm gdm3 lightdm lxdm xdm kdm nodm slim entrance)
  for dm in "${other_dms[@]}"; do
    if systemctl is-enabled "$dm" &>/dev/null; then
      echo -e "${RED}✗ Display manager en conflicto: $dm${NC}"
      return 1
    fi
  done
  
  # Check SDDM configuration file
  if [[ ! -f "/etc/sddm.conf" ]]; then
    echo -e "${RED}✗ Archivo de configuración SDDM no encontrado${NC}"
    return 1
  fi
  
  # Check if corners theme is installed
  if [[ ! -d "/usr/share/sddm/themes/corners" ]]; then
    echo -e "${RED}✗ Theme corners no encontrado${NC}"
    return 1
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
  check_root
  
  # Install SDDM and theme
  if ! install_sddm_theme; then
    exit 1
  fi
  
  # Configure SDDM
  if ! configure_sddm; then
    exit 1
  fi
  
  # Enable service
  if ! enable_sddm_service; then
    exit 1
  fi
  
  # Validate SDDM configuration
  validate_sddm_default
  
  echo -e "${GREEN}✓ SDDM instalado y configurado${NC}"
}

# Run main function
main "$@"
