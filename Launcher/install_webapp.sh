#!/usr/bin/env bash

# WebApp Creator Installer
# Installs webapp-creator and related scripts automatically

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration source directory (should be passed as parameter)
REPO_DIR="${1:-$HOME/Myconfig}"

# Function to display header
show_header() {
  clear
  echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║        WebApp Creator Installer        ║${NC}"
  echo -e "${CYAN}║      Instalación Automática            ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
  echo
}

# Function to validate source directory
validate_source_directory() {
  local source_dir="$1"
  
  if [[ ! -d "$source_dir" ]]; then
    echo -e "${RED}✗ Directorio fuente no encontrado: $source_dir${NC}"
    return 1
  fi
  
  if [[ ! -d "$source_dir/Launcher" ]]; then
    echo -e "${RED}✗ Estructura de repositorio inválida en: $source_dir${NC}"
    echo -e "${YELLOW}Se espera directorio: Launcher/${NC}"
    return 1
  fi
  
  return 0
}

# Function to check dependencies
check_dependencies() {
  echo -e "${BLUE}Verificando dependencias...${NC}"
  
  # Check for Chromium
  if ! command -v chromium &>/dev/null; then
    echo -e "${YELLOW}Chromium no encontrado. Instalando...${NC}"
    if command -v pacman &>/dev/null; then
      sudo pacman -S chromium --noconfirm
      if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Chromium instalado${NC}"
      else
        echo -e "${RED}✗ Error al instalar Chromium${NC}"
        return 1
      fi
    else
      echo -e "${RED}✗ No se pudo instalar Chromium automáticamente${NC}"
      return 1
    fi
  else
    echo -e "${GREEN}✓ Chromium encontrado${NC}"
  fi
  
  return 0
}

# Function to install webapp creator
install_webapp_creator() {
  local source_dir="$1"
  local launcher_dir="$source_dir/Launcher"
  local webapp_script="$launcher_dir/webapp-creator.sh"
  local launcher_script="$launcher_dir/launcher.sh"
  local gamemode_script="$source_dir/i3/scripts/game-mode.sh"
  local webapps_archive="$launcher_dir/webapps.tar.gz"
  
  local bin_dir="$HOME/.local/bin"
  local apps_dir="$HOME/.local/share/applications"
  local icons_dir="$HOME/.local/share/icons/webapp-icons"
  
  echo -e "${BLUE}Instalando WebApp Creator...${NC}"
  
  # Create directories
  mkdir -p "$bin_dir"
  mkdir -p "$apps_dir"
  mkdir -p "$icons_dir"
  
  # Copy main script
  if [[ -f "$webapp_script" ]]; then
    cp "$webapp_script" "$bin_dir/webapp-creator"
    chmod +x "$bin_dir/webapp-creator"
    echo -e "${GREEN}  ✓ webapp-creator copiado${NC}"
  else
    echo -e "${RED}  ✗ webapp-creator.sh no encontrado${NC}"
    return 1
  fi
  
  # Copy launcher script
  if [[ -f "$launcher_script" ]]; then
    cp "$launcher_script" "$bin_dir/launcher.sh"
    chmod +x "$bin_dir/launcher.sh"
    echo -e "${GREEN}  ✓ launcher.sh copiado${NC}"
  else
    echo -e "${YELLOW}  ! launcher.sh no encontrado, omitiendo...${NC}"
  fi
  
  # Copy game-mode script
  if [[ -f "$gamemode_script" ]]; then
    cp "$gamemode_script" "$bin_dir/game-mode.sh"
    chmod +x "$bin_dir/game-mode.sh"
    echo -e "${GREEN}  ✓ game-mode.sh copiado${NC}"
  else
    echo -e "${YELLOW}  ! game-mode.sh no encontrado, omitiendo...${NC}"
  fi
  
  # Create symlink for wac-game
  if [[ -f "$bin_dir/game-mode.sh" && ! -L "$bin_dir/wac-game" ]]; then
    ln -s "$bin_dir/game-mode.sh" "$bin_dir/wac-game"
    echo -e "${GREEN}  ✓ Symlink creado: wac-game -> game-mode.sh${NC}"
  fi
  
  # Create desktop entry
  cat > "$apps_dir/webapp-creator.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=WebApp Creator
Comment=Create web applications from URLs
Exec=webapp-creator
Icon=webapp-creator
Terminal=false
Categories=Utility;Development;
StartupNotify=true
EOF
  
  echo -e "${GREEN}  ✓ Entrada de escritorio creada${NC}"
  
  # Extract webapps if available
  if [[ -f "$webapps_archive" ]]; then
    echo -e "${BLUE}Extrayendo webapps por defecto...${NC}"
    tar -xzf "$webapps_archive" -C "$HOME/.local/share/applications/"
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}  ✓ Webapps por defecto instaladas${NC}"
    else
      echo -e "${YELLOW}  ! Error al extraer webapps${NC}"
    fi
  else
    echo -e "${YELLOW}  ! webapps.tar.gz no encontrado, omitiendo...${NC}"
  fi
  
  return 0
}

# Function to check PATH
check_path() {
  local bin_dir="$HOME/.local/bin"
  
  if ! is_in_path "$bin_dir"; then
    echo -e "${YELLOW}⚠ $bin_dir no está en PATH${NC}"
    echo -e "${BLUE}Agrega esta línea a tu ~/.bashrc o ~/.zshrc:${NC}"
    echo -e "${WHITE}export PATH=\"\$PATH:$bin_dir\"${NC}"
    echo
  else
    echo -e "${GREEN}✓ $bin_dir está en PATH${NC}"
  fi
}

# Function to show completion
show_completion() {
  echo
  echo -e "${GREEN}✓ ¡WebApp Creator instalado exitosamente!${NC}"
  echo
  echo -e "${WHITE}Archivos instalados:${NC}"
  echo -e "${BLUE}  • webapp-creator - Script principal${NC}"
  echo -e "${BLUE}  • launcher.sh - Lanzador de aplicaciones${NC}"
  echo -e "${BLUE}  • game-mode.sh - Modo juego (wac-game)${NC}"
  echo -e "${BLUE}  • webapp-creator.desktop - Entrada de escritorio${NC}"
  echo
  echo -e "${YELLOW}Uso:${NC}"
  echo -e "${WHITE}  webapp-creator - Crear nueva webapp${NC}"
  echo -e "${WHITE}  wac-game - Activar modo juego${NC}"
  echo
}

# Function to check if directory is in PATH
is_in_path() {
  local dir="$1"
  case ":$PATH:" in
    *":$dir:"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Main execution
main() {
  show_header
  
  echo -e "${BLUE}Directorio fuente: $REPO_DIR${NC}"
  echo
  
  # Validate source directory
  if ! validate_source_directory "$REPO_DIR"; then
    echo -e "${RED}✗ No se puede continuar sin un directorio fuente válido${NC}"
    exit 1
  fi
  
  # Check dependencies
  if ! check_dependencies; then
    echo -e "${RED}✗ Error en verificación de dependencias${NC}"
    exit 1
  fi
  
  echo
  
  # Install webapp creator
  if install_webapp_creator "$REPO_DIR"; then
    # Check PATH
    check_path
    
    # Show completion
    show_completion
  else
    echo -e "${RED}✗ Error en la instalación${NC}"
    exit 1
  fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
