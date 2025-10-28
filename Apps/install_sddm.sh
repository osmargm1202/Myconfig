#!/usr/bin/env bash

# SDDM Local Theme Installer
# Installs and configures SDDM with a local theme

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

# Global variables for selected theme
SELECTED_THEME_FILE=""
SELECTED_THEME_NAME=""

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
  echo -e "${CYAN}║       Local Themes Selector           ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
  echo
}

# Function to select theme from local files
select_theme() {
  local themes_dir="/home/osmar/Myconfig/sddm"
  local selected_theme=""
  local clean_name=""
  
  # Check if themes directory exists
  if [[ ! -d "$themes_dir" ]]; then
    echo -e "${RED}✗ Directorio de themes no encontrado: $themes_dir${NC}"
    return 1
  fi
  
  # Find all theme archives using portable method
  local theme_files=()
  local theme_names=()
  local file
  
  for file in "$themes_dir"/*.tar.gz "$themes_dir"/*.tar.xz; do
    if [[ -f "$file" ]]; then
      theme_files+=("$(basename "$file")")
      # Get clean name (without extension)
      clean_name="${theme_files[-1]%.tar.*}"
      theme_names+=("$clean_name")
    fi
  done
  
  # Check if any themes found
  if [[ ${#theme_files[@]} -eq 0 ]]; then
    echo -e "${RED}✗ No se encontraron themes en $themes_dir${NC}"
    return 1
  fi
  
  # Show info about found themes
  echo -e "${CYAN}✓ Encontrados ${#theme_files[@]} theme(s):${NC}"
  for i in "${!theme_names[@]}"; do
    echo -e "${BLUE}  • ${theme_names[i]}${NC}"
  done
  echo
  
  # Show theme selection
  if [[ "$FORCE_YES" == true ]]; then
    # In force mode, select first theme
    selected_theme="${theme_files[0]}"
    clean_name="${theme_names[0]}"
    echo -e "${GREEN}✓ Seleccionando primer theme: $clean_name${NC}"
  elif [[ "$HAS_GUM" == true ]]; then
    # Use gum for selection with clean names
    local choice_index
    choice_index=$(gum choose --header="Selecciona un theme de SDDM:" "${theme_names[@]}")
    
    # Validate selection
    if [[ -z "$choice_index" ]]; then
      echo -e "${RED}✗ No se seleccionó ningún theme${NC}"
      return 1
    fi
    
    # Find index of selected name
    local i
    for i in "${!theme_names[@]}"; do
      if [[ "${theme_names[i]}" == "$choice_index" ]]; then
        selected_theme="${theme_files[i]}"
        clean_name="${theme_names[i]}"
        break
      fi
    done
  else
    # Fallback to traditional prompt
    echo -e "${CYAN}Themes disponibles:${NC}"
    for i in "${!theme_names[@]}"; do
      echo -e "  ${GREEN}$((i+1))${NC}. ${theme_names[i]}"
    done
    echo -ne "${YELLOW}Selecciona un theme (1-${#theme_names[@]}):${NC} "
    read -r choice </dev/tty
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#theme_files[@]} ]]; then
      selected_theme="${theme_files[$((choice-1))]}"
      clean_name="${theme_names[$((choice-1))]}"
    else
      echo -e "${RED}✗ Selección inválida${NC}"
      return 1
    fi
  fi
  
  # Validate that a theme was selected
  if [[ -z "$selected_theme" ]]; then
    echo -e "${RED}✗ No se pudo determinar el theme seleccionado${NC}"
    return 1
  fi
  
  # Set global variables
  SELECTED_THEME_FILE="$selected_theme"
  SELECTED_THEME_NAME="$clean_name"
  
  echo -e "${GREEN}✓ Theme seleccionado: $clean_name (${selected_theme})${NC}"
  
  return 0
}

# Function to check if running as root
check_root() {
  if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}✗ Este script no debe ejecutarse como root${NC}"
    echo -e "${BLUE}Ejecuta como usuario normal, se pedirán permisos sudo cuando sea necesario${NC}"
    exit 1
  fi
}

# Function to install SDDM and extract theme
install_sddm_theme() {
  local theme_name="$1"
  local theme_file="$2"
  local themes_dir="/home/osmar/Myconfig/sddm"
  local temp_dir="/tmp/sddm-theme-$$"
  
  # Install SDDM
  echo -e "${BLUE}Instalando SDDM...${NC}"
  sudo pacman -S sddm --noconfirm
  
  # Extract theme
  echo -e "${BLUE}Extrayendo theme: $theme_name...${NC}"
  
  # Create temporary directory
  mkdir -p "$temp_dir"
  
  # Extract archive
  if [[ "$theme_file" == *.tar.gz ]]; then
    tar -xzf "$themes_dir/$theme_file" -C "$temp_dir"
  elif [[ "$theme_file" == *.tar.xz ]]; then
    tar -xJf "$themes_dir/$theme_file" -C "$temp_dir"
  else
    echo -e "${RED}✗ Formato de archivo no soportado: $theme_file${NC}"
    return 1
  fi
  
  # Find extracted theme directory
  local extracted_dir=""
  extracted_dir=$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d | head -n1)
  
  if [[ -z "$extracted_dir" ]]; then
    echo -e "${RED}✗ No se pudo encontrar el directorio del theme extraído${NC}"
    rm -rf "$temp_dir"
    return 1
  fi
  
  # Move theme to SDDM themes directory
  sudo mkdir -p "/usr/share/sddm/themes/"
  sudo cp -r "$extracted_dir" "/usr/share/sddm/themes/$theme_name"
  
  # Clean up
  rm -rf "$temp_dir"
  
  echo -e "${GREEN}✓ Theme $theme_name instalado en /usr/share/sddm/themes/${NC}"
}

# Function to configure SDDM
configure_sddm() {
  local theme_name="$1"
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
Current=$theme_name

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
  local theme_name="$1"
  
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
  
  # Check if selected theme is installed
  if [[ ! -d "/usr/share/sddm/themes/$theme_name" ]]; then
    echo -e "${RED}✗ Theme $theme_name no encontrado${NC}"
    return 1
  fi
}

# Function to show completion message
show_completion() {
  local theme_name="$1"
  local autologin_user="$2"
  
  echo
  echo -e "${GREEN}✓ ¡SDDM con theme $theme_name instalado y configurado!${NC}"
  echo
  echo -e "${WHITE}Configuración aplicada:${NC}"
  echo -e "${BLUE}  • Display Manager: SDDM${NC}"
  echo -e "${BLUE}  • Theme: $theme_name${NC}"
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
  
  # Show header
  show_header
  
  # Select theme
  if ! select_theme; then
    exit 1
  fi
  
  # Install SDDM and extract theme
  if ! install_sddm_theme "$SELECTED_THEME_NAME" "$SELECTED_THEME_FILE"; then
    exit 1
  fi
  
  # Configure SDDM
  if ! configure_sddm "$SELECTED_THEME_NAME"; then
    exit 1
  fi
  
  # Enable service
  if ! enable_sddm_service; then
    exit 1
  fi
  
  # Validate SDDM configuration
  if ! validate_sddm_default "$SELECTED_THEME_NAME"; then
    exit 1
  fi
  
  # Show completion message
  local autologin_user=""
  if [[ -n "$USER" ]] && grep -q "User=$USER" /etc/sddm.conf; then
    autologin_user="$USER"
  fi
  
  show_completion "$SELECTED_THEME_NAME" "$autologin_user"
}

# Run main function
main "$@"
