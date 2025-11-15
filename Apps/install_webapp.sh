#!/usr/bin/env bash

# WebApp Creator Installer
# Installs and configures WebApp Creator with all dependencies

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
LOCAL_BIN="$HOME/.local/bin"

# Function to display header
show_header() {
  clear
  echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║       WebApp Creator Installer        ║${NC}"
  echo -e "${CYAN}║    Complete Setup & Configuration     ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
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

# Function to validate repository
validate_repository() {
  local repo_dir="$1"
  
  if [[ ! -d "$repo_dir" ]]; then
    echo -e "${RED}✗ Directorio del repositorio no encontrado: $repo_dir${NC}"
    return 1
  fi
  
  if [[ ! -d "$repo_dir/Launcher" ]]; then
    echo -e "${RED}✗ Directorio Launcher no encontrado en: $repo_dir${NC}"
    return 1
  fi
  
  if [[ ! -f "$repo_dir/Launcher/webapp-creator.sh" ]]; then
    echo -e "${RED}✗ Script webapp-creator.sh no encontrado${NC}"
    return 1
  fi
  
  return 0
}


# Function to create webapp-creator desktop file
create_desktop_file() {
  local apps_dir="$HOME/.local/share/applications"
  local icons_dir="$HOME/.local/share/icons/webapp-icons"
  local desktop_file="$apps_dir/webapp-creator.desktop"
  local icon_path="$icons_dir/webapp-creator.png"
  local bin_path="$LOCAL_BIN/webapp-creator"

  mkdir -p "$apps_dir" "$icons_dir"

  echo -e "${BLUE}Creando entrada de escritorio...${NC}"

  # Create icon for webapp-creator
  if command -v convert &>/dev/null; then
    convert -size 128x128 xc:transparent -fill "#4A90E2" -draw "circle 64,64 64,20" \
      -fill white -font DejaVu-Sans-Bold -pointsize 14 -gravity center \
      -annotate +0+0 "WEB\nAPP" "$icon_path" 2>/dev/null
    echo -e "${GREEN}✓ Icono creado con ImageMagick${NC}"
  else
    echo -e "${YELLOW}ImageMagick no encontrado, usando icono de respaldo${NC}"
    # Try to copy a system icon as fallback
    for sys_icon in /usr/share/icons/hicolor/*/apps/preferences-system.png \
      /usr/share/pixmaps/preferences-system.png \
      /usr/share/icons/*/*/apps/application-default-icon.png; do
      if [[ -f "$sys_icon" ]]; then
        cp "$sys_icon" "$icon_path" 2>/dev/null && break
      fi
    done

    if [[ ! -f "$icon_path" ]]; then
      # Create simple text-based icon as last resort
      if command -v convert &>/dev/null; then
        echo -e "${YELLOW}Creando icono simple${NC}"
        convert -size 128x128 xc:"#4A90E2" -font DejaVu-Sans-Bold -pointsize 16 \
          -fill white -gravity center -annotate +0+0 "WEBAPP\nCREATOR" \
          "$icon_path" 2>/dev/null
      fi
      
      # If convert fails or is not available, create a placeholder
      if [[ ! -f "$icon_path" ]]; then
        echo -e "${YELLOW}Creando icono placeholder${NC}"
        touch "$icon_path"
      fi
    fi
  fi

  # Create the desktop file
  cat >"$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=WebApp Creator
Comment=Create and manage web applications using Chromium
Exec=$bin_path
Icon=$icon_path
Categories=Development;System;Utility;
Keywords=webapp;chromium;browser;application;
NoDisplay=false
StartupNotify=true
Terminal=true
StartupWMClass=webapp-creator
EOF

  chmod +x "$desktop_file"
  echo -e "${GREEN}✓ Archivo de escritorio creado${NC}"
}

# Function to import default webapps
import_default_webapps() {
  local webapps_archive="$REPO_DIR/Launcher/webapps.tar.gz"
  
  if [[ ! -f "$webapps_archive" ]]; then
    echo -e "${YELLOW}No se encontró archivo de webapps por defecto${NC}"
    return 0
  fi
  
  echo -e "${BLUE}Importando webapps por defecto...${NC}"

  # Create temporary directory with fallback
  local temp_dir
  if command -v mktemp &>/dev/null; then
    temp_dir=$(mktemp -d)
  else
    temp_dir="/tmp/webapps_install_$$"
    mkdir -p "$temp_dir"
  fi
  
  tar -xzf "$webapps_archive" -C "$temp_dir"

  # Import icons
  if [[ -d "$temp_dir/webapp-icons" ]]; then
    cp -r "$temp_dir/webapp-icons/"* "$HOME/.local/share/icons/webapp-icons/" 2>/dev/null
    echo -e "${GREEN}  ✓ Iconos importados${NC}"
  fi

  # Import applications
  if [[ -d "$temp_dir/applications" ]]; then
    cp "$temp_dir/applications/"*.desktop "$HOME/.local/share/applications/" 2>/dev/null
    echo -e "${GREEN}  ✓ Aplicaciones importadas${NC}"
  fi

  # Import config
  if [[ -f "$temp_dir/webapps.json" ]]; then
    cp "$temp_dir/webapps.json" "$HOME/.local/share/webapp-sync/"
    echo -e "${GREEN}  ✓ Configuración importada${NC}"
  fi

  rm -rf "$temp_dir"
  echo -e "${GREEN}✓ Webapps por defecto instaladas${NC}"
}

# Function to install webapp creator
install_webapp_creator() {
  echo -e "${BLUE}Instalando WebApp Creator...${NC}"

  local launcher_dir="$REPO_DIR/Launcher"
  local webapp_script="$launcher_dir/webapp-creator.sh"
  local launcher_script="$launcher_dir/launcher.sh"
  local gamemode_script="$repo_dir/i3/scripts/game-mode.sh"

  # Create directories
  mkdir -p "$LOCAL_BIN"
  mkdir -p "$HOME/.local/share/applications"
  mkdir -p "$HOME/.local/share/icons/webapp-icons"
  mkdir -p "$HOME/.local/share/webapp-sync"
  echo -e "${GREEN}✓ Directorios creados${NC}"

  # Copy main webapp-creator script
  if [[ -f "$webapp_script" ]]; then
    cp -f "$webapp_script" "$LOCAL_BIN/webapp-creator"
    chmod +x "$LOCAL_BIN/webapp-creator"
    echo -e "${GREEN}✓ Script principal copiado${NC}"
  else
    echo -e "${RED}✗ Script webapp-creator.sh no encontrado${NC}"
    return 1
  fi

  # Copy additional scripts
  local scripts_copied=0
  
  if [[ -f "$launcher_script" ]]; then
    cp -f "$launcher_script" "$LOCAL_BIN/launcher.sh"
    chmod +x "$LOCAL_BIN/launcher.sh"
    echo -e "${GREEN}✓ launcher.sh copiado${NC}"
    ((scripts_copied++))
  fi

  if [[ -f "$gamemode_script" ]]; then
    cp -f "$gamemode_script" "$LOCAL_BIN/game-mode.sh"
    chmod +x "$LOCAL_BIN/game-mode.sh"
    echo -e "${GREEN}✓ game-mode.sh copiado${NC}"
    ((scripts_copied++))
  fi

  # Create symlinks for easier access
  if [[ ! -L "$LOCAL_BIN/wac" ]]; then
    ln -s "$LOCAL_BIN/webapp-creator" "$LOCAL_BIN/wac"
    echo -e "${GREEN}✓ Symlink creado: wac -> webapp-creator${NC}"
  fi

  if [[ -f "$LOCAL_BIN/game-mode.sh" && ! -L "$LOCAL_BIN/wac-game" ]]; then
    ln -s "$LOCAL_BIN/game-mode.sh" "$LOCAL_BIN/wac-game"
    echo -e "${GREEN}✓ Symlink creado: wac-game -> game-mode.sh${NC}"
  fi

  echo -e "${BLUE}Scripts adicionales instalados: $scripts_copied${NC}"
  return 0
}

# Function to check PATH and give instructions
check_path_instructions() {
  if ! is_in_path "$LOCAL_BIN"; then
    echo
    echo -e "${YELLOW}⚠ Advertencia: $LOCAL_BIN no está en tu PATH${NC}"
    echo -e "${BLUE}Agrega esta línea a tu archivo de configuración del shell:${NC}"
    echo
    echo -e "${WHITE}Para Bash/Zsh (añadir a ~/.bashrc o ~/.zshrc):${NC}"
    echo -e "${GREEN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo
    echo -e "${WHITE}Para Fish (ejecutar una vez):${NC}"
    echo -e "${GREEN}fish_add_path ~/.local/bin${NC}"
    echo
    echo -e "${BLUE}O ejecuta temporalmente: ${WHITE}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
  else
    echo -e "${GREEN}✓ $LOCAL_BIN está en tu PATH${NC}"
  fi
}

# Function to show completion message
show_completion() {
  echo
  echo -e "${GREEN}✓ ¡WebApp Creator instalado exitosamente!${NC}"
  echo
  echo -e "${WHITE}Puedes usarlo de las siguientes formas:${NC}"
  echo -e "${BLUE}  • Ejecuta 'webapp-creator' desde terminal${NC}"
  echo -e "${BLUE}  • Ejecuta 'wac' (atajo)${NC}"
  echo -e "${BLUE}  • Busca 'WebApp Creator' en tu menú de aplicaciones${NC}"
  echo -e "${BLUE}  • Ejecútalo desde rofi/launcher${NC}"
  echo
  echo -e "${WHITE}Scripts adicionales disponibles:${NC}"
  echo -e "${BLUE}  • launcher.sh - Lanzador de webapps${NC}"
  echo -e "${BLUE}  • game-mode.sh - Modo juego (wac-game)${NC}"
  echo
  echo -e "${YELLOW}Nota: Reinicia tu terminal o ejecuta 'source ~/.bashrc' para usar los comandos${NC}"
  echo
}

# Main execution
main() {
  # Validate repository
  if ! validate_repository "$REPO_DIR"; then
    exit 1
  fi
  
  # Install WebApp Creator
  if ! install_webapp_creator; then
    exit 1
  fi
  
  # Create desktop file
  create_desktop_file
  
  # Import default webapps
  import_default_webapps
  
  echo -e "${GREEN}✓ WebApp Creator instalado${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
