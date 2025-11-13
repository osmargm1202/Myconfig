#!/usr/bin/env bash

# Icon Themes Installer
# Installs icon themes from Icons/ directory to ~/.local/share/icons/

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
  echo -e "${CYAN}║       Icon Themes Installer           ║${NC}"
  echo -e "${CYAN}║   Install icon themes to system       ║${NC}"
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
  
  return 0
}

# Function to install icon themes
install_icon_themes() {
  local source_dir="$1"
  local icons_source="$source_dir/Icons"
  local icons_target="$HOME/.local/share/icons"
  
  echo -e "${BLUE}Instalando temas de iconos...${NC}"
  echo
  
  # Create target directory if it doesn't exist
  mkdir -p "$icons_target"
  
  if [[ ! -d "$icons_source" ]]; then
    echo -e "${YELLOW}  ○ Directorio Icons no encontrado, saltando...${NC}"
    echo
    return 0
  fi
  
  # Copy each icon theme directory (exclude individual files like orgmos.png)
  local copied=0
  for item in "$icons_source"/*; do
    if [[ -d "$item" ]]; then
      local theme_name=$(basename "$item")
      local target_theme="$icons_target/$theme_name"
      
      echo -e "${BLUE}Instalando tema de iconos: $theme_name${NC}"
      
      # Remove existing theme if it exists
      if [[ -d "$target_theme" ]]; then
        echo -e "${YELLOW}  • Reemplazando tema existente${NC}"
        rm -rf "$target_theme"
      fi
      
      # Copy theme directory
      if cp -r "$item" "$target_theme"; then
        echo -e "${GREEN}  ✓ Instalado $theme_name${NC}"
        ((copied++))
      else
        echo -e "${RED}  ✗ Error al instalar $theme_name${NC}"
      fi
    fi
  done
  
  if [[ $copied -gt 0 ]]; then
    echo -e "${GREEN}✓ $copied tema(s) de iconos instalado(s)${NC}"
  else
    echo -e "${YELLOW}No se encontraron temas de iconos para instalar${NC}"
  fi
  
  echo
}

# Function to show completion message
show_completion() {
  echo
  echo -e "${GREEN}✓ ¡Instalación de iconos completada!${NC}"
  echo
  echo -e "${WHITE}Resultado:${NC}"
  echo -e "${BLUE}  • Ubicación: ~/.local/share/icons/${NC}"
  echo -e "${BLUE}  • Puedes cambiar el tema de iconos desde la configuración de tu entorno de escritorio${NC}"
  echo
}

# Main execution
main() {
  show_header
  
  # Validate source directory
  if ! validate_source_directory "$REPO_DIR"; then
    exit 1
  fi
  
  # Install icon themes
  install_icon_themes "$REPO_DIR"
  
  # Show completion message
  show_completion
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

