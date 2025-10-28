#!/usr/bin/env bash

# Chaotic-AUR Repository Installer
# Installs chaotic-aur repository and enables multilib for Arch Linux

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
  echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║    Chaotic-AUR Repository Installer       ║${NC}"
  echo -e "${CYAN}║     Arch Linux Package Repository Setup   ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
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

# Function to print debug/log messages
print_debug() {
  local message="$1"
  echo -e "${BLUE}[DEBUG]${NC} $message"
}

print_success() {
  local message="$1"
  echo -e "${GREEN}✓${NC} $message"
}

print_error() {
  local message="$1"
  echo -e "${RED}✗${NC} $message"
}

print_warning() {
  local message="$1"
  echo -e "${YELLOW}⚠${NC} $message"
}

print_info() {
  local message="$1"
  echo -e "${CYAN}ℹ${NC} $message"
}

# Function to check if chaotic-aur is already configured
check_chaotic_installed() {
  if [[ -f /etc/pacman.d/chaotic-mirrorlist ]] && grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    return 0
  else
    return 1
  fi
}

# Function to check if multilib is enabled
check_multilib_enabled() {
  if grep -q "\[multilib\]" /etc/pacman.conf && ! grep -q "^#" <<< "$(grep -A1 "\[multilib\]" /etc/pacman.conf | head -1)"; then
    return 0
  else
    return 1
  fi
}

# Function to enable multilib repository
enable_multilib() {
  print_info "Verificando repositorio multilib..."
  
  if check_multilib_enabled; then
    print_success "Multilib ya está habilitado"
    return 0
  fi
  
  print_debug "Multilib no está habilitado, habilitando..."
  
  if [[ ! -w /etc/pacman.conf ]]; then
    print_error "No tienes permisos de escritura en /etc/pacman.conf"
    return 1
  fi
  
  # Create backup of pacman.conf
  local backup_file="/etc/pacman.conf.backup.$(date +%Y%m%d_%H%M%S)"
  print_debug "Creando backup: $backup_file"
  sudo cp /etc/pacman.conf "$backup_file"
  
  # Uncomment multilib if it's commented
  print_debug "Descomentando sección [multilib]..."
  sudo sed -i 's/^#\[multilib\]/[multilib]/' /etc/pacman.conf
  sudo sed -i '/^\[multilib\]/,/^$/ s/^#Include = /Include = /' /etc/pacman.conf
  
  print_success "Sección multilib descomentada"
  
  # Sync multilib repository
  print_debug "Sincronizando repositorio multilib..."
  if sudo pacman -Sy multilib > /dev/null 2>&1; then
    print_success "Repositorio multilib sincronizado"
    return 0
  else
    print_error "Error al sincronizar multilib"
    print_warning "Restaurando backup..."
    sudo cp "$backup_file" /etc/pacman.conf
    return 1
  fi
}

# Function to import GPG key
import_gpg_key() {
  print_info "Importando clave GPG de chaotic-aur..."
  
  local key_id="3056513887B78AEB"
  
  print_debug "Recibiendo clave desde keyserver.ubuntu.com..."
  if sudo pacman-key --recv-key "$key_id" --keyserver keyserver.ubuntu.com; then
    print_success "Clave GPG recibida"
  else
    print_error "Error al recibir clave GPG"
    return 1
  fi
  
  print_debug "Firmando localmente la clave..."
  if sudo pacman-key --lsign-key "$key_id"; then
    print_success "Clave GPG firmada localmente"
    return 0
  else
    print_error "Error al firmar clave GPG"
    return 1
  fi
}

# Function to install chaotic-keyring and chaotic-mirrorlist
install_chaotic_packages() {
  print_info "Instalando chaotic-keyring y chaotic-mirrorlist..."
  
  local cdn_url="https://cdn-mirror.chaotic.cx/chaotic-aur"
  
  print_debug "Descargando chaotic-keyring..."
  if sudo pacman -U --noconfirm "${cdn_url}/chaotic-keyring.pkg.tar.zst" > /dev/null 2>&1; then
    print_success "chaotic-keyring instalado"
  else
    print_error "Error al instalar chaotic-keyring"
    return 1
  fi
  
  print_debug "Descargando chaotic-mirrorlist..."
  if sudo pacman -U --noconfirm "${cdn_url}/chaotic-mirrorlist.pkg.tar.zst" > /dev/null 2>&1; then
    print_success "chaotic-mirrorlist instalado"
  else
    print_error "Error al instalar chaotic-mirrorlist"
    return 1
  fi
  
  return 0
}

# Function to configure chaotic-aur in pacman.conf
configure_chaotic_repo() {
  print_info "Configurando chaotic-aur en /etc/pacman.conf..."
  
  if grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    print_success "chaotic-aur ya está configurado"
    return 0
  fi
  
  print_debug "Agregando sección [chaotic-aur] al final de /etc/pacman.conf..."
  
  if echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf > /dev/null; then
    print_success "Configuración agregada a /etc/pacman.conf"
    return 0
  else
    print_error "Error al agregar configuración"
    return 1
  fi
}

# Function to sync repositories
sync_repositories() {
  print_info "Sincronizando todos los repositorios..."
  print_debug "Ejecutando: sudo pacman -Syu"
  
  if sudo pacman -Syu; then
    print_success "Repositorios sincronizados correctamente"
    return 0
  else
    print_error "Error al sincronizar repositorios"
    return 1
  fi
}

# Function to show completion message
show_completion() {
  echo
  echo -e "${GREEN}✓ ¡Chaotic-AUR y Multilib configurados exitosamente!${NC}"
  echo
  echo -e "${WHITE}Repositorios habilitados:${NC}"
  echo -e "${BLUE}  • multilib${NC}"
  echo -e "${BLUE}  • chaotic-aur${NC}"
  echo
  echo -e "${WHITE}Siguientes pasos:${NC}"
  echo -e "${CYAN}  • Puedes instalar paquetes desde chaotic-aur${NC}"
  echo -e "${CYAN}  • Aplicaciones de 32-bit disponibles con multilib${NC}"
  echo -e "${CYAN}  • Ejecuta: pacman -Ss <paquete> para buscar${NC}"
  echo
}

# Function to handle errors and cleanup
handle_error() {
  print_error "Error durante la instalación de chaotic-aur"
  print_warning "Revisa los logs arriba para más detalles"
  exit 1
}

# Main installation function
install_chaotic_aur() {
  print_debug "Iniciando instalación de chaotic-aur..."
  
  # Step 1: Enable multilib
  if ! enable_multilib; then
    handle_error
  fi
  
  # Step 2: Import GPG key
  if ! import_gpg_key; then
    handle_error
  fi
  
  # Step 3: Install chaotic packages
  if ! install_chaotic_packages; then
    handle_error
  fi
  
  # Step 4: Configure chaotic-aur in pacman.conf
  if ! configure_chaotic_repo; then
    handle_error
  fi
  
  # Step 5: Sync repositories
  if ! sync_repositories; then
    handle_error
  fi
  
  return 0
}

# Main execution
main() {
  check_root
  show_header
  
  # Check if already installed
  if check_chaotic_installed; then
    print_success "Chaotic-AUR ya está configurado en tu sistema"
    echo -e "${BLUE}No se requiere ninguna acción adicional.${NC}"
    exit 0
  fi
  
  print_info "Este script configurará:"
  echo -e "${CYAN}  1. Repositorio multilib (32-bit support)${NC}"
  echo -e "${CYAN}  2. Repositorio chaotic-aur${NC}"
  echo -e "${CYAN}  3. Sincronizar repositorios${NC}"
  echo
  
  if ! ask_confirmation "¿Deseas continuar con la instalación?"; then
    print_warning "Instalación cancelada por el usuario"
    exit 0
  fi
  
  echo
  
  # Install chaotic-aur
  if ! install_chaotic_aur; then
    handle_error
  fi
  
  # Show completion message
  show_completion
}

# Run main function
main "$@"

