#!/usr/bin/env bash

# Wallpapers Setup Script
# Copies wallpapers to home directory and configures i3

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
REPO_DIR="${1:-$HOME/Myconfig}"
WALLPAPERS_SOURCE="$REPO_DIR/Wallpapers"
WALLPAPERS_TARGET="$HOME/Wallpapers"
WALLPAPER_STATE_FILE="$HOME/.config/current_wallpaper"

# Check if Gum is available
HAS_GUM=false
if command -v gum &>/dev/null; then
  HAS_GUM=true
  export GUM_CHOOSE_SELECTED_FOREGROUND="#87CEEB"
  export GUM_CHOOSE_CURSOR_FOREGROUND="#00BFFF"
  export GUM_CONFIRM_SELECTED_FOREGROUND="#87CEEB"
fi

# Function removed - no confirmations needed

# Function to display header
show_header() {
  clear
  echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║        Wallpapers Installer           ║${NC}"
  echo -e "${CYAN}║    Setup backgrounds for i3WM         ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
  echo
}

# Function to validate source directory
validate_source_directory() {
  if [[ ! -d "$WALLPAPERS_SOURCE" ]]; then
    echo -e "${RED}✗ Directorio de wallpapers no encontrado: $WALLPAPERS_SOURCE${NC}"
    return 1
  fi
  
  local wallpaper_count=$(find "$WALLPAPERS_SOURCE" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" \) 2>/dev/null | wc -l)
  
  if [[ $wallpaper_count -eq 0 ]]; then
    echo -e "${RED}✗ No se encontraron wallpapers en: $WALLPAPERS_SOURCE${NC}"
    return 1
  fi
  
  echo -e "${GREEN}✓ Encontrados $wallpaper_count wallpapers${NC}"
  return 0
}

# Function to copy wallpapers
copy_wallpapers() {
  echo -e "${BLUE}Copiando wallpapers...${NC}"
  
  # Create target directory
  mkdir -p "$WALLPAPERS_TARGET"
  
  # Check if target already has wallpapers
  local existing_count=$(find "$WALLPAPERS_TARGET" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" \) 2>/dev/null | wc -l)
  
  if [[ $existing_count -gt 0 ]]; then
    echo -e "${YELLOW}Se encontraron $existing_count wallpapers existentes${NC}"
    echo -e "${BLUE}Copiando nuevos wallpapers sin crear backup...${NC}"
  fi
  
  # Copy wallpapers
  local copied=0
  local skipped=0
  
  while IFS= read -r -d '' wallpaper; do
    local filename=$(basename "$wallpaper")
    local target_file="$WALLPAPERS_TARGET/$filename"
    
    if [[ ! -f "$target_file" ]]; then
      cp "$wallpaper" "$target_file"
      ((copied++))
    else
      ((skipped++))
    fi
  done < <(find "$WALLPAPERS_SOURCE" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" \) -print0 2>/dev/null)
  
  echo -e "${GREEN}✓ Wallpapers copiados: $copied${NC}"
  if [[ $skipped -gt 0 ]]; then
    echo -e "${YELLOW}✓ Wallpapers omitidos (ya existían): $skipped${NC}"
  fi
  
  return 0
}


# Function to show completion message
show_completion() {
  local wallpaper_count="$1"
  
  echo
  echo -e "${GREEN}✓ ¡Wallpapers instalados exitosamente!${NC}"
  echo
  echo -e "${WHITE}Resultado:${NC}"
  echo -e "${BLUE}  • Wallpapers copiados: $wallpaper_count${NC}"
  echo -e "${BLUE}  • Ubicación: $WALLPAPERS_TARGET${NC}"
  echo
  echo -e "${WHITE}Siguiente paso:${NC}"
  echo -e "${CYAN}  • Los wallpapers están listos para usar${NC}"
  echo -e "${CYAN}  • i3 los manejará automáticamente si está configurado${NC}"
  echo
  echo -e "${YELLOW}Nota:${NC}"
  echo -e "${BLUE}  • Para configurar cambio automático, instala las configuraciones de i3${NC}"
  echo -e "${BLUE}  • El atajo Super+Alt+Space se configura con i3${NC}"
  echo
}

# Main execution
main() {
  show_header
  
  echo -e "${WHITE}Este script instalará:${NC}"
  echo -e "${BLUE}  1. Copia wallpapers del repo a ~/Wallpapers${NC}"
  echo -e "${BLUE}  2. Omite wallpapers que ya existen${NC}"
  echo
  echo -e "${BLUE}Directorio fuente: $WALLPAPERS_SOURCE${NC}"
  echo -e "${BLUE}Directorio destino: $WALLPAPERS_TARGET${NC}"
  echo
  
  # Validate source directory
  if ! validate_source_directory; then
    echo -e "${RED}✗ No se puede continuar sin wallpapers válidos${NC}"
    exit 1
  fi
  
  echo
  echo -e "${GREEN}Iniciando instalación automática...${NC}"
  echo
  
  # Copy wallpapers
  if ! copy_wallpapers; then
    echo -e "${RED}✗ Error al copiar wallpapers${NC}"
    exit 1
  fi
  
  # Count total wallpapers
  local total_wallpapers=$(find "$WALLPAPERS_TARGET" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" \) 2>/dev/null | wc -l)
  
  # Show completion
  show_completion "$total_wallpapers"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
