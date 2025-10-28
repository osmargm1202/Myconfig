#!/usr/bin/env bash

# SDDM ORGMOS Theme Installer
# Installs and configures SDDM with ORGMOS theme

# Support for non-interactive mode
FORCE_YES=false
ENABLE_AUTOLOGIN=false
SELECTED_THEME=""

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
    --theme)
      SELECTED_THEME="$2"
      shift 2
      ;;
    -h|--help)
      echo "Uso: $0 [opciones]"
      echo "Opciones:"
      echo "  -y, --yes, --force    Instalar sin confirmaciones"
      echo "  --autologin          Activar autologin automáticamente"
      echo "  --theme TEMA         Seleccionar tema específico"
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

# Function to select SDDM color theme
select_sddm_theme() {
  local theme_source="$1"
  local themes=()
  local theme_labels=()
  
  # Find all .conf files
  for conf in "$theme_source"/*.conf; do
    if [[ -f "$conf" ]]; then
      local filename=$(basename "$conf" .conf)
      case "$filename" in
        "theme.conf")
          themes+=("theme.conf")
          theme_labels+=("Default - Original sky blue")
          ;;
        "tokyo-night")
          themes+=("tokyo-night.conf")
          theme_labels+=("Tokyo Night ⭐ - Dark with bright sky blue button")
          ;;
        "panther")
          themes+=("panther.conf")
          theme_labels+=("Panther - Dark minimal")
          ;;
        "lynx")
          themes+=("lynx.conf")
          theme_labels+=("Lynx - Light theme")
          ;;
      esac
    fi
  done
  
  if [[ ${#themes[@]} -eq 0 ]]; then
    echo -e "${YELLOW}⚠ No se encontraron temas, usando default${NC}"
    echo "Default"
    return 0
  fi
  
  local selected_theme
  local selected_index
  
  # Use gum if available
  if command -v gum &>/dev/null && [[ "$HAS_GUM" == true ]]; then
    echo -e "${BLUE}Selecciona el tema de color:${NC}" >&2
    echo >&2
    
    # Build label array for gum
    local labels_string=$(printf '%s\n' "${theme_labels[@]}")
    
    selected_label=$(echo "$labels_string" | gum choose --header "🌙 SDDM Color Theme Selector" 2>&1)
    
    if [[ -z "$selected_label" ]]; then
      echo -e "${YELLOW}Selección cancelada, usando Default${NC}" >&2
      echo "Default"
      return 0
    fi
    
    # Find index of selected label
    for i in "${!theme_labels[@]}"; do
      if [[ "${theme_labels[$i]}" == "$selected_label" ]]; then
        selected_index=$i
        break
      fi
    done
  else
    # Fallback to traditional menu
    echo -e "${BLUE}Selecciona el tema de color:${NC}" >&2
    local i=1
    for label in "${theme_labels[@]}"; do
      echo "  $i) $label" >&2
      ((i++))
    done
    echo >&2
    
    local choice
    read -p "Selecciona tema (1-${#themes[@]}): " choice
    selected_index=$((choice - 1))
  fi
  
  if [[ -n "$selected_index" && $selected_index -ge 0 && $selected_index -lt ${#themes[@]} ]]; then
    selected_theme="${themes[$selected_index]}:${theme_labels[$selected_index]}"
    echo "$selected_theme"
  else
    echo -e "${YELLOW}Selección inválida, usando Default${NC}" >&2
    echo "Default:Default - Original sky blue"
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
  
  # Apply selected theme (chosen before sudo)
  echo
  if [[ -n "$SELECTED_THEME" ]]; then
    local theme_file="${SELECTED_THEME%%:*}"
    local theme_name="${SELECTED_THEME#*:}"
    
    echo -e "${BLUE}Aplicando tema: ${CYAN}$theme_name${NC}"
    
    # Copy selected theme to theme.conf
    if sudo cp "$theme_source/$theme_file" "$theme_dest/theme.conf" 2>/dev/null; then
      echo -e "${GREEN}✓ Tema '$theme_name' aplicado${NC}"
    else
      echo -e "${RED}✗ Error al aplicar tema${NC}"
    fi
  else
    # Fallback: use tokyo-night as default
    if [[ -f "$theme_source/tokyo-night.conf" ]]; then
      echo -e "${BLUE}Aplicando Tokyo Night (por defecto)${NC}"
      sudo cp "$theme_source/tokyo-night.conf" "$theme_dest/theme.conf"
      echo -e "${GREEN}✓ Tokyo Night aplicado${NC}"
    fi
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

# Function to select theme before sudo
select_theme_before_sudo() {
  # Try to find repository directory
  local repo_dir=""
  if [[ -d "/home/osmar/Myconfig" ]]; then
    repo_dir="/home/osmar/Myconfig"
  else
    repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
  fi
  
  local theme_source="$repo_dir/sddm/orgmos-sddm"
  
  if [[ ! -d "$theme_source" ]]; then
    echo -e "${YELLOW}⚠ Theme source no encontrado${NC}"
    echo "tokyo-night.conf:Tokyo Night"
    return 0
  fi
  
  local themes=()
  local theme_labels=()
  
  # Find all .conf files
  for conf in "$theme_source"/*.conf; do
    if [[ -f "$conf" ]]; then
      local filename=$(basename "$conf" .conf)
      case "$filename" in
        "theme.conf")
          themes+=("theme.conf")
          theme_labels+=("Default - Original sky blue")
          ;;
        "tokyo-night")
          themes+=("tokyo-night.conf")
          theme_labels+=("Tokyo Night ⭐ - Dark with bright sky blue button")
          ;;
        "panther")
          themes+=("panther.conf")
          theme_labels+=("Panther - Dark minimal")
          ;;
        "lynx")
          themes+=("lynx.conf")
          theme_labels+=("Lynx - Light theme")
          ;;
      esac
    fi
  done
  
  if [[ ${#themes[@]} -eq 0 ]]; then
    echo "tokyo-night.conf:Tokyo Night"
    return 0
  fi
  
  local selected_label
  local selected_index
  
  # Use gum if available
  if command -v gum &>/dev/null && [[ "$HAS_GUM" == true ]]; then
    selected_label=$(printf '%s\n' "${theme_labels[@]}" | gum choose --header "🌙 SDDM Color Theme Selector")
    
    if [[ -z "$selected_label" ]]; then
      # Use Tokyo Night as default
      for i in "${!theme_labels[@]}"; do
        if [[ "${theme_labels[$i]}" == "Tokyo Night ⭐ - Dark with bright sky blue button" ]]; then
          selected_index=$i
          break
        fi
      done
    else
      # Find index of selected label
      for i in "${!theme_labels[@]}"; do
        if [[ "${theme_labels[$i]}" == "$selected_label" ]]; then
          selected_index=$i
          break
        fi
      done
    fi
  else
    # Fallback menu
    echo -e "${BLUE}Selecciona el tema de color:${NC}"
    local i=1
    for label in "${theme_labels[@]}"; do
      echo "  $i) $label"
      ((i++))
    done
    echo
    
    local choice
    read -p "Selecciona tema (1-${#themes[@]}): " choice
    selected_index=$((choice - 1))
  fi
  
  if [[ -n "$selected_index" && $selected_index -ge 0 && $selected_index -lt ${#themes[@]} ]]; then
    echo "${themes[$selected_index]}:${theme_labels[$selected_index]}"
  else
    echo "tokyo-night.conf:Tokyo Night"
  fi
}

# Main execution
main() {
  check_root
  
  # Select theme before sudo operations
  if [[ "$FORCE_YES" == false && -z "$SELECTED_THEME" ]]; then
    show_header
    echo -e "${BLUE}Preparando instalación de SDDM...${NC}"
    echo
    SELECTED_THEME=$(select_theme_before_sudo)
  elif [[ -z "$SELECTED_THEME" ]]; then
    SELECTED_THEME="tokyo-night.conf:Tokyo Night"
  fi
  
  show_header
  
  # Export selected theme for use in install function
  export SELECTED_THEME
  
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
