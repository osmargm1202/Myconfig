#!/usr/bin/env bash

# Starship Configuration Installer
# Installs Starship prompt configuration

# Support for non-interactive mode
FORCE_YES=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes|--force)
      FORCE_YES=true
      shift
      ;;
    -h|--help)
      echo "Uso: $0 [opciones]"
      echo "Opciones:"
      echo "  -y, --yes, --force    Instalar sin confirmaciones"
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
  export GUM_CHOOSE_SELECTED_FOREGROUND="#87CEEB"
  export GUM_CHOOSE_CURSOR_FOREGROUND="#00BFFF"
  export GUM_CONFIRM_SELECTED_FOREGROUND="#87CEEB"
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
  echo -e "${CYAN}║      Starship Config Installer        ║${NC}"
  echo -e "${CYAN}║     Terminal Prompt Theme Setup       ║${NC}"
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

# Function to install Starship configuration
install_starship_config() {
  local repo_dir="$1"
  local config_source="$repo_dir/starship/starship.toml"
  local config_dest="$HOME/.config/starship.toml"
  local backup_file=""
  
  # Check if starship is installed
  if ! command -v starship &>/dev/null; then
    echo -e "${RED}✗ Starship no está instalado${NC}"
    echo -e "${BLUE}Instala starship primero con: pacman -S starship${NC}"
    echo -e "${YELLOW}¡No olvides que ya está en tu lista de paquetes pkg_core.lst!${NC}"
    return 1
  fi
  
  # Check if source file exists
  if [[ ! -f "$config_source" ]]; then
    echo -e "${RED}✗ Archivo de configuración no encontrado: $config_source${NC}"
    return 1
  fi
  
  # Check if destination exists and create backup
  if [[ -f "$config_dest" ]]; then
    backup_file="$config_dest.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$config_dest" "$backup_file"
    echo -e "${YELLOW}✗ Backup creado: $(basename "$backup_file")${NC}"
  fi
  
  # Copy configuration
  cp "$config_source" "$config_dest"
  echo -e "${GREEN}✓ Configuración instalada en: $config_dest${NC}"
  
  # Verify fish/bash config has starship initialization
  local has_fish_init=false
  local has_bash_init=false
  
  # Check fish config
  if [[ -f "$HOME/.config/fish/config.fish" ]]; then
    if grep -q "starship init fish" "$HOME/.config/fish/config.fish" 2>/dev/null; then
      has_fish_init=true
      echo -e "${GREEN}✓ Fish config verificado${NC}"
    else
      echo -e "${YELLOW}⚠ Fish config no tiene inicialización de starship${NC}"
      echo -e "${BLUE}Agrega esto a ~/.config/fish/config.fish:${NC}"
      echo -e "${WHITE}  if type -q starship${NC}"
      echo -e "${WHITE}      starship init fish | source${NC}"
      echo -e "${WHITE}  end${NC}"
    fi
  fi
  
  # Check bash config
  if [[ -f "$HOME/.bashrc" ]]; then
    if grep -q "starship init bash" "$HOME/.bashrc" 2>/dev/null; then
      has_bash_init=true
      echo -e "${GREEN}✓ Bash config verificado${NC}"
    else
      echo -e "${YELLOW}⚠ Bash config no tiene inicialización de starship${NC}"
      echo -e "${BLUE}Agrega esto a ~/.bashrc:${NC}"
      echo -e "${WHITE}  eval \"\\$(starship init bash)\"${NC}"
    fi
  fi
  
  return 0
}

# Function to show completion message
show_completion() {
  echo
  echo -e "${GREEN}✓ ¡Configuración de Starship instalada!${NC}"
  echo
  echo -e "${WHITE}Configuración aplicada:${NC}"
  echo -e "${BLUE}  • Archivo: ~/.config/starship.toml${NC}"
  echo -e "${BLUE}  • Theme: Personalizado${NC}"
  echo -e "${BLUE}  • Estado: Listo para usar${NC}"
  echo
  echo -e "${WHITE}Notas importantes:${NC}"
  echo -e "${CYAN}  • Abre una nueva terminal para ver los cambios${NC}"
  echo -e "${CYAN}  • O recarga tu configuración con: exec fish${NC}"
  echo -e "${CYAN}  • Si usas bash: source ~/.bashrc${NC}"
  echo
  echo -e "${YELLOW}El prompt mostrará:${NC}"
  echo -e "${BLUE}  • Nombre del proyecto${NC}"
  echo -e "${BLUE}  • Rama de git (si aplica)${NC}"
  echo -e "${BLUE}  • Email de gcloud autenticado${NC}"
  echo -e "${BLUE}  • Otros datos del entorno${NC}"
  echo
}

# Main execution
main() {
  check_root
  show_header
  
  # Get repository directory
  local repo_dir=""
  if [[ -d "/home/osmar/Myconfig" ]]; then
    repo_dir="/home/osmar/Myconfig"
  else
    # Try to find the repository
    repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
  fi
  
  echo -e "${BLUE}Directorio del repositorio: $repo_dir${NC}"
  echo
  
  # Install configuration
  if ! install_starship_config "$repo_dir"; then
    exit 1
  fi
  
  # Show completion message
  show_completion
}

# Run main function
main "$@"

