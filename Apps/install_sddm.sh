#!/usr/bin/env bash

# SDDM ORGMOS Theme Installer
# Installs and configures SDDM with ORGMOS theme

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
  echo -e "${CYAN}║       ORGMOS Login Manager           ║${NC}"
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

# Function to install SDDM
install_sddm() {
  echo -e "${BLUE}Instalando SDDM...${NC}"
  sudo pacman -S sddm --noconfirm
  
  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ SDDM instalado exitosamente${NC}"
  else
    echo -e "${RED}✗ Error al instalar SDDM${NC}"
    return 1
  fi
}

# Function to install ORGMOS theme
install_orgmos_theme() {
  local repo_dir=""
  
  # Try to find repository directory
  if [[ -d "/home/osmar/Myconfig" ]]; then
    repo_dir="/home/osmar/Myconfig"
  else
    # Try parent directory
    repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
  fi
  
  local theme_source="$repo_dir/sddm/orgmos-sddm"
  local theme_dest="/usr/share/sddm/themes/orgmos-sddm"
  
  # Check if source exists
  if [[ ! -d "$theme_source" ]]; then
    echo -e "${RED}✗ Theme orgmos-sddm no encontrado en: $theme_source${NC}"
    return 1
  fi
  
  echo -e "${BLUE}Instalando theme ORGMOS...${NC}"
  
  # Remove existing theme if present
  if [[ -d "$theme_dest" ]]; then
    sudo rm -rf "$theme_dest"
  fi
  
  # Copy theme folder
  sudo mkdir -p "/usr/share/sddm/themes"
  sudo cp -r "$theme_source" "$theme_dest"
  
  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Theme orgmos-sddm instalado en /usr/share/sddm/themes/${NC}"
  else
    echo -e "${RED}✗ Error al instalar theme${NC}"
    return 1
  fi
}

# Function to configure SDDM
configure_sddm() {
  local sddm_conf="/etc/sddm.conf"
  local backup_conf="/etc/sddm.conf.backup.$(date +%Y%m%d_%H%M%S)"
  
  # Create backup of existing config
  if [[ -f "$sddm_conf" ]]; then
    sudo cp "$sddm_conf" "$backup_conf"
    echo -e "${BLUE}Backup creado: $(basename "$backup_conf")${NC}"
  fi
  
  # Ask about autologin
  local enable_autologin="n"
  
  if [[ "$ENABLE_AUTOLOGIN" == true ]]; then
    # Explicit --autologin flag was passed
    enable_autologin="y"
    echo -e "${GREEN}✓ Autologin activado (flag --autologin)${NC}"
  else
    # Always ask, regardless of FORCE_YES
    if [[ "$HAS_GUM" == true ]]; then
      # Use gum for confirmation
      if gum confirm "¿Activar autologin (inicio automático sin contraseña)?"; then
        enable_autologin="y"
      fi
    else
      # Fallback to traditional prompt
      echo -e "${YELLOW}¿Activar autologin (inicio automático sin contraseña)? (y/N):${NC} "
      read -r response </dev/tty
      if [[ "$response" =~ ^[Yy]$ ]]; then
        enable_autologin="y"
      fi
    fi
  fi
  
  local autologin_user=""
  if [[ "$enable_autologin" =~ ^[Yy]$ ]]; then
    autologin_user="$USER"
    echo -e "${GREEN}✓ Autologin configurado para: $USER${NC}"
  else
    echo -e "${BLUE}→ Autologin desactivado${NC}"
  fi
  
  # Create SDDM configuration
  echo -e "${BLUE}Configurando SDDM...${NC}"
  sudo tee "$sddm_conf" > /dev/null << EOF
[Autologin]
Relogin=false
Session=
User=$autologin_user

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Theme]
Current=orgmos-sddm

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
  
  echo -e "${GREEN}✓ Configuración de SDDM creada${NC}"
}

# Function to enable SDDM service
enable_sddm_service() {
  # Disable other display managers first
  local other_dms=(gdm gdm3 lightdm lxdm xdm kdm nodm slim entrance)
  
  for dm in "${other_dms[@]}"; do
    if systemctl is-enabled "$dm" &>/dev/null; then
      echo -e "${BLUE}Deshabilitando $dm...${NC}"
      sudo systemctl disable "$dm" 2>/dev/null || true
    fi
  done
  
  # Stop any running display managers
  for dm in "${other_dms[@]}"; do
    if systemctl is-active "$dm" &>/dev/null; then
      echo -e "${BLUE}Deteniendo $dm...${NC}"
      sudo systemctl stop "$dm" 2>/dev/null || true
    fi
  done
  
  # Enable SDDM
  echo -e "${BLUE}Habilitando SDDM...${NC}"
  sudo systemctl enable sddm
  
  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ SDDM habilitado${NC}"
  else
    echo -e "${RED}✗ Error al habilitar SDDM${NC}"
    return 1
  fi
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
  
  # Check if orgmos-sddm theme is installed
  if [[ ! -d "/usr/share/sddm/themes/orgmos-sddm" ]]; then
    echo -e "${RED}✗ Theme orgmos-sddm no encontrado${NC}"
    return 1
  fi
  
  echo -e "${GREEN}✓ Validación completa${NC}"
}

# Function to show completion message
show_completion() {
  local autologin_user="$1"
  
  echo
  echo -e "${GREEN}✓ ¡SDDM con theme ORGMOS instalado y configurado!${NC}"
  echo
  echo -e "${WHITE}Configuración aplicada:${NC}"
  echo -e "${BLUE}  • Display Manager: SDDM${NC}"
  echo -e "${BLUE}  • Theme: orgmos-sddm${NC}"
  echo -e "${BLUE}  • Estado: Validado como display manager por defecto${NC}"
  if [[ -n "$autologin_user" ]]; then
    echo -e "${BLUE}  • Autologin: activado para $autologin_user${NC}"
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
  show_header
  
  # Install SDDM
  if ! install_sddm; then
    exit 1
  fi
  
  # Install ORGMOS theme
  if ! install_orgmos_theme; then
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
  if ! validate_sddm_default; then
    exit 1
  fi
  
  # Show completion message
  local autologin_user=""
  if [[ -n "$USER" ]] && grep -q "User=$USER" /etc/sddm.conf 2>/dev/null; then
    autologin_user="$USER"
  fi
  
  show_completion "$autologin_user"
}

# Run main function
main "$@"
