#!/usr/bin/env bash

# Simple Installer - Downloads repository and runs setup
# Compatible with curl -fsSL | bash
# This script only handles repo download/update and executes setup.sh

# Ensure we're running with bash for better compatibility
if [ -z "$BASH_VERSION" ]; then
  echo "This script requires bash. Please run with: bash <(curl -fsSL your-url)"
  exit 1
fi

# Parse update flag before main execution
if [[ "$1" == "--update" ]]; then
  # Colors for output
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  NC='\033[0m'
  
  # Determine script directory
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  
  echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║         ORGMOS Updater                ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
  echo
  
  # Check if in git repository
  if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
    echo -e "${RED}✗ No se encontró un repositorio git en: $SCRIPT_DIR${NC}"
    echo -e "${YELLOW}Este directorio no es un repositorio git válido${NC}"
    exit 1
  fi
  
  # Check if git is installed
  if ! command -v git &>/dev/null; then
    echo -e "${RED}✗ Git no está instalado${NC}"
    exit 1
  fi
  
  # Update repository
  echo -e "${BLUE}Actualizando repositorio...${NC}"
  cd "$SCRIPT_DIR"
  
  if git pull; then
    echo -e "${GREEN}✓ Repositorio actualizado exitosamente${NC}"
  else
    echo -e "${RED}✗ Error al actualizar el repositorio${NC}"
    exit 1
  fi
  
  # Update permissions on all .sh files
  echo -e "${BLUE}Actualizando permisos de ejecución...${NC}"
  
  if [[ -d "$SCRIPT_DIR/Apps" ]]; then
    chmod +x "$SCRIPT_DIR/Apps"/*.sh 2>/dev/null
    echo -e "${GREEN}  ✓ Apps/${NC}"
  fi
  
  if [[ -d "$SCRIPT_DIR/Launcher" ]]; then
    chmod +x "$SCRIPT_DIR/Launcher"/*.sh 2>/dev/null
    echo -e "${GREEN}  ✓ Launcher/${NC}"
  fi
  
  if [[ -d "$SCRIPT_DIR/i3/scripts" ]]; then
    chmod +x "$SCRIPT_DIR/i3/scripts"/*.sh 2>/dev/null
    echo -e "${GREEN}  ✓ i3/scripts/${NC}"
  fi
  
  if [[ -d "$SCRIPT_DIR/polybar/scripts" ]]; then
    chmod +x "$SCRIPT_DIR/polybar/scripts"/*.sh 2>/dev/null
    echo -e "${GREEN}  ✓ polybar/scripts/${NC}"
  fi
  
  echo
  echo -e "${GREEN}✓ ¡Actualización completada!${NC}"
  echo -e "${BLUE}ORGMOS ha sido actualizado a la última versión${NC}"
  exit 0
fi

# Repository information
REPO_URL="https://github.com/osmargm1202/Myconfig.git"
REPO_NAME="Myconfig"

# Colors (basic, no fancy features)
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Function to display simple header
show_header() {
  clear
  echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║        Quick System Installer         ║${NC}"
  echo -e "${CYAN}║      Downloading & Running Setup      ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
  echo
}

# Function to detect environment
detect_environment() {
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  
  # Check if we're in the repository structure
  if [[ -d "$SCRIPT_DIR/Launcher" && -d "$SCRIPT_DIR/Apps" && -f "$SCRIPT_DIR/setup.sh" ]]; then
    IS_STANDALONE=false
    REPO_DIR="$SCRIPT_DIR"
    echo -e "${GREEN}✓ Ejecutándose desde repositorio local${NC}"
  else
    IS_STANDALONE=true
    REPO_DIR="$HOME/$REPO_NAME"
    echo -e "${BLUE}→ Modo instalación remota${NC}"
  fi
}

# Function to ensure git is available
ensure_git() {
  if command -v git &>/dev/null; then
    return 0
  fi
  
  echo -e "${YELLOW}Git no está instalado, instalando...${NC}"
  if command -v pacman &>/dev/null; then
    sudo pacman -S git --noconfirm
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✓ Git instalado exitosamente${NC}"
      return 0
    else
      echo -e "${RED}✗ Error al instalar git${NC}"
      exit 1
    fi
  else
    echo -e "${RED}✗ No se pudo instalar git automáticamente (pacman no encontrado)${NC}"
    echo -e "${YELLOW}Por favor instala git manualmente y vuelve a ejecutar${NC}"
    exit 1
  fi
}

# Function to clone or update repository
setup_repository() {
  if [[ "$IS_STANDALONE" == false ]]; then
    echo -e "${GREEN}✓ Ya estás en el repositorio${NC}"
    return 0
  fi
  
  ensure_git
  
  if [[ -d "$REPO_DIR" ]]; then
    echo -e "${BLUE}Actualizando repositorio existente...${NC}"
    cd "$REPO_DIR" && git pull
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✓ Repositorio actualizado${NC}"
    else
      echo -e "${RED}✗ Error al actualizar repositorio${NC}"
      exit 1
    fi
  else
    echo -e "${BLUE}Clonando repositorio desde: $REPO_URL${NC}"
    git clone "$REPO_URL" "$REPO_DIR"
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✓ Repositorio clonado exitosamente${NC}"
    else
      echo -e "${RED}✗ Error al clonar repositorio${NC}"
      exit 1
    fi
  fi
  
  echo -e "${GREEN}✓ Repositorio listo en: $REPO_DIR${NC}"
  
  # Give execution permissions to all scripts in Apps directory
  if [[ -d "$REPO_DIR/Apps" ]]; then
    echo -e "${BLUE}Otorgando permisos de ejecución a scripts en Apps/...${NC}"
    chmod +x "$REPO_DIR/Apps"/*.sh 2>/dev/null
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✓ Permisos otorgados a scripts en Apps/${NC}"
    else
      echo -e "${YELLOW}⚠ No se encontraron scripts .sh en Apps/ o ya tienen permisos${NC}"
    fi
  fi
  
  # Give execution permissions to all scripts in Launcher directory
  if [[ -d "$REPO_DIR/Launcher" ]]; then
    echo -e "${BLUE}Otorgando permisos de ejecución a scripts en Launcher/...${NC}"
    chmod +x "$REPO_DIR/Launcher"/*.sh 2>/dev/null
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✓ Permisos otorgados a scripts en Launcher/${NC}"
    else
      echo -e "${YELLOW}⚠ No se encontraron scripts .sh en Launcher/ o ya tienen permisos${NC}"
    fi
  fi
  
  # Give execution permissions to all scripts in i3/scripts directory
  if [[ -d "$REPO_DIR/i3/scripts" ]]; then
    echo -e "${BLUE}Otorgando permisos de ejecución a scripts en i3/scripts/...${NC}"
    chmod +x "$REPO_DIR/i3/scripts"/*.sh 2>/dev/null
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✓ Permisos otorgados a scripts en i3/scripts/${NC}"
    else
      echo -e "${YELLOW}⚠ No se encontraron scripts .sh en i3/scripts/ o ya tienen permisos${NC}"
    fi
  fi
  
  # Give execution permissions to all scripts in polybar/scripts directory
  if [[ -d "$REPO_DIR/polybar/scripts" ]]; then
    echo -e "${BLUE}Otorgando permisos de ejecución a scripts en polybar/scripts/...${NC}"
    chmod +x "$REPO_DIR/polybar/scripts"/*.sh 2>/dev/null
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✓ Permisos otorgados a scripts en polybar/scripts/${NC}"
    else
      echo -e "${YELLOW}⚠ No se encontraron scripts .sh en polybar/scripts/ o ya tienen permisos${NC}"
    fi
  fi
}

# Function to run setup script
run_setup() {
  local setup_script="$REPO_DIR/setup.sh"
  
  if [[ ! -f "$setup_script" ]]; then
    echo -e "${RED}✗ Script setup.sh no encontrado en: $setup_script${NC}"
    exit 1
  fi
  
  # Make setup script executable
  chmod +x "$setup_script"
  echo -e "${GREEN}✓ Permisos otorgados a setup.sh${NC}"
  
  echo
  echo -e "${CYAN}→ Ejecutando configurador principal...${NC}"
  echo
  
  # Execute setup script
  "$setup_script"
  local exit_code=$?
  
  echo
  if [[ $exit_code -eq 0 ]]; then
    echo -e "${GREEN}✓ Configuración completada exitosamente${NC}"
  else
    echo -e "${YELLOW}⚠ Setup terminó con código: $exit_code${NC}"
  fi
  
  return $exit_code
}

# Main execution
main() {
  show_header
  
  echo -e "${BLUE}Este instalador:${NC}"
  echo -e "${GREEN}  1. Descarga/actualiza el repositorio${NC}"
  echo -e "${GREEN}  2. Ejecuta el configurador principal${NC}"
  echo -e "${GREEN}  3. Te da acceso a todas las opciones de instalación${NC}"
  echo
  
  # Detect environment
  detect_environment
  echo
  
  # Setup repository if needed
  if [[ "$IS_STANDALONE" == true ]]; then
    setup_repository
    echo
  fi
  
  # Run setup script
  run_setup
}

# Execute main function
main "$@"
