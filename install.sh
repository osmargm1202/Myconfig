#!/usr/bin/env bash

# Install Script for WebApp Creator and System Configuration
# This script installs webapp-creator and system configurations
# Can be run directly via curl or from cloned repository

# Ensure we're running with bash for better compatibility
if [ -z "$BASH_VERSION" ]; then
  echo "This script requires bash. Please run with: bash <(curl -fsSL your-url)"
  exit 1
fi

# Repository information
REPO_URL="https://github.com/osmargm1202/Myconfig.git"
REPO_NAME="Myconfig"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to check if directory is in PATH
is_in_path() {
  local dir="$1"
  case ":$PATH:" in
    *":$dir:"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Function to check and install Gum if needed
check_install_gum() {
  if command -v gum &>/dev/null; then
    return 0
  fi
  
  echo -e "${BLUE}Gum no está instalado. Es necesario para una mejor experiencia de usuario.${NC}"
  echo -e "${YELLOW}¿Instalar Gum ahora? (y/N):${NC} "
  read -r install_gum </dev/tty
  
  if [[ "$install_gum" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Instalando Gum...${NC}"
    if sudo pacman -S gum --noconfirm; then
      echo -e "${GREEN}✓ Gum instalado exitosamente${NC}"
      return 0
    else
      echo -e "${RED}✗ Error al instalar Gum${NC}"
      echo -e "${YELLOW}Continuando sin Gum (funcionalidad básica)${NC}"
      return 1
    fi
  else
    echo -e "${YELLOW}Continuando sin Gum (funcionalidad básica)${NC}"
    return 1
  fi
}

# Gum color configuration
export GUM_CHOOSE_SELECTED_FOREGROUND="#87CEEB"  # Sky Blue
export GUM_CHOOSE_CURSOR_FOREGROUND="#00BFFF"    # Deep Sky Blue
export GUM_CONFIRM_SELECTED_FOREGROUND="#87CEEB"
export GUM_INPUT_CURSOR_FOREGROUND="#00BFFF"
export GUM_INPUT_PROMPT_FOREGROUND="#87CEEB"
export GUM_FILTER_INDICATOR_FOREGROUND="#00BFFF"
export GUM_FILTER_MATCH_FOREGROUND="#87CEEB"

# Function to ask for confirmation with Gum support
ask_confirmation() {
  local message="$1"
  local default="${2:-N}"  # Default to N if not specified
  
  if [[ "$HAS_GUM" == true ]]; then
    # Try Gum first
    if gum confirm "$message" 2>/dev/null; then
      return 0
    elif [[ -c /dev/tty ]]; then
      # Try Gum with TTY
      gum confirm "$message" </dev/tty 2>/dev/null
      return $?
    fi
  fi
  
  # Fallback to traditional prompt
  echo -e "${YELLOW}$message (y/N):${NC} "
  local response
  if [[ -c /dev/tty ]]; then
    read -r response </dev/tty
  else
    read -r response
  fi
  [[ "$response" =~ ^[Yy]$ ]]
  return $?
}

# Function to get input with Gum support
get_input() {
  local prompt="$1"
  local placeholder="${2:-}"
  
  if [[ "$HAS_GUM" == true ]]; then
    # Try Gum first
    local result
    if [[ -n "$placeholder" ]]; then
      result=$(gum input --prompt "$prompt " --placeholder "$placeholder" 2>/dev/null)
    else
      result=$(gum input --prompt "$prompt " 2>/dev/null)
    fi
    
    if [[ -n "$result" ]] || [[ -c /dev/tty ]]; then
      if [[ -z "$result" && -c /dev/tty ]]; then
        # Try Gum with TTY
        if [[ -n "$placeholder" ]]; then
          result=$(gum input --prompt "$prompt " --placeholder "$placeholder" </dev/tty 2>/dev/null)
        else
          result=$(gum input --prompt "$prompt " </dev/tty 2>/dev/null)
        fi
      fi
      echo "$result"
      return 0
    fi
  fi
  
  # Fallback to traditional prompt
  echo -ne "${YELLOW}$prompt${NC} "
  local input
  if [[ -c /dev/tty ]]; then
    read -r input </dev/tty
  else
    read -r input
  fi
  echo "$input"
}

# Function to detect if we're in repository or standalone
detect_environment() {
  # Use readlink if available, fallback to realpath or plain dirname
  if command -v readlink &>/dev/null; then
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
  elif command -v realpath &>/dev/null; then
    SCRIPT_DIR="$(dirname "$(realpath "$0")")"
  else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  fi

  # Check if we're in the repository structure
  if [[ -d "$SCRIPT_DIR/Launcher" && -d "$SCRIPT_DIR/Apps" ]]; then
    IS_STANDALONE=false
    REPO_DIR="$SCRIPT_DIR"
  else
    IS_STANDALONE=true
    REPO_DIR="$HOME/$REPO_NAME"
  fi

  LAUNCHER_DIR="$REPO_DIR/Launcher"
  APPS_DIR="$REPO_DIR/Apps"
  WEBAPP_CREATOR="$LAUNCHER_DIR/webapp-creator.sh"
  LAUNCHER_SCRIPT="$LAUNCHER_DIR/launcher.sh"
  GAMEMODE_SCRIPT="$LAUNCHER_DIR/game-mode.sh"
  SYSTEM_BIN="/usr/local/bin"
  LOCAL_BIN="$HOME/.local/bin"
}

# Function to clone repository if running standalone
clone_repository() {
  if [[ "$IS_STANDALONE" == true ]]; then
    show_header
    echo -e "${BLUE}Detectado modo independiente - descargando repositorio...${NC}"
    echo

    # Check if repository already exists
    if [[ -d "$REPO_DIR" ]]; then
      echo -e "${YELLOW}El repositorio ya existe en: $REPO_DIR${NC}"

      # Check if git is installed before trying to update
      if ! command -v git &>/dev/null; then
        echo -e "${YELLOW}Git no está instalado, instalando...${NC}"
        if command -v pacman &>/dev/null; then
          sudo pacman -S git --noconfirm
          if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✓ Git instalado exitosamente${NC}"
          else
            echo -e "${RED}✗ Error al instalar git${NC}"
            exit 1
          fi
        else
          echo -e "${RED}✗ No se pudo instalar git automáticamente (pacman no encontrado)${NC}"
          exit 1
        fi
      fi

      echo -e "${BLUE}Actualizando repositorio automáticamente...${NC}"
      cd "$REPO_DIR" && git pull
      if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Repositorio actualizado${NC}"
      else
        echo -e "${RED}✗ Error al actualizar repositorio${NC}"
        exit 1
      fi
    else
      # Clone repository
      echo -e "${BLUE}Clonando repositorio desde: $REPO_URL${NC}"

      # Check if git is installed before trying to clone
      if ! command -v git &>/dev/null; then
        echo -e "${YELLOW}Git no está instalado, instalando...${NC}"
        if command -v pacman &>/dev/null; then
          sudo pacman -S git --noconfirm
          if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✓ Git instalado exitosamente${NC}"
          else
            echo -e "${RED}✗ Error al instalar git${NC}"
            exit 1
          fi
        else
          echo -e "${RED}✗ No se pudo instalar git automáticamente (pacman no encontrado)${NC}"
          echo -e "${BLUE}Por favor instala git manualmente y vuelve a ejecutar el script${NC}"
          exit 1
        fi
      fi

      # Clone the repository
      git clone "$REPO_URL" "$REPO_DIR"
      if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Repositorio clonado exitosamente${NC}"
      else
        echo -e "${RED}✗ Error al clonar repositorio${NC}"
        echo -e "${YELLOW}Asegúrate de que la URL sea correcta${NC}"
        exit 1
      fi
    fi

    echo
    echo -e "${GREEN}✓ Repositorio listo en: $REPO_DIR${NC}"
    echo -e "${BLUE}El script usará este directorio para las configuraciones${NC}"
    echo
  fi
}

# Function to display header
show_header() {
  clear
  echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║      System & WebApp Installer        ║${NC}"
  echo -e "${CYAN}║        Complete Setup Tool            ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
  echo
}

# Function to check chromium installation
check_chromium() {
  if command -v chromium &>/dev/null; then
    echo -e "${GREEN}✓ Chromium is already installed${NC}"
    return 0
  elif command -v chromium-browser &>/dev/null; then
    echo -e "${GREEN}✓ Chromium browser is already installed${NC}"
    return 0
  else
    echo -e "${YELLOW}⚠ Chromium not found${NC}"
    echo -e "${BLUE}WebApp Creator requires Chromium to create web applications${NC}"
    echo
    echo -ne "${YELLOW}Would you like to install Chromium now? (y/N): ${NC}"
    read -r install_choice </dev/tty

    if [[ "$install_choice" =~ ^[Yy]$ ]]; then
      echo -e "${BLUE}Installing Chromium...${NC}"
      if sudo pacman -S chromium; then
        echo -e "${GREEN}✓ Chromium installed successfully${NC}"
        return 0
      else
        echo -e "${RED}✗ Failed to install Chromium${NC}"
        echo -e "${YELLOW}You can install it manually later with: sudo pacman -S chromium${NC}"
        return 1
      fi
    else
      echo -e "${YELLOW}Skipping Chromium installation${NC}"
      echo -e "${BLUE}Note: WebApp Creator won't work properly without Chromium${NC}"
      return 1
    fi
  fi
}

# Function to create webapp-creator desktop file
create_webapp_creator_desktop() {
  local apps_dir="$HOME/.local/share/applications"
  local icons_dir="$HOME/.local/share/icons/webapp-icons"
  local desktop_file="$apps_dir/webapp-creator.desktop"
  local icon_path="$icons_dir/webapp-creator.png"
  local bin_path="$HOME/.local/bin/webapp-creator"

  mkdir -p "$apps_dir" "$icons_dir"

  echo -e "${BLUE}Creating WebApp Creator desktop entry...${NC}"

  # Create icon for webapp-creator
  if command -v convert &>/dev/null; then
    convert -size 128x128 xc:transparent -fill "#4A90E2" -draw "circle 64,64 64,20" \
      -fill white -font DejaVu-Sans-Bold -pointsize 14 -gravity center \
      -annotate +0+0 "WEB\nAPP" "$icon_path" 2>/dev/null
    echo -e "${GREEN}✓ Created WebApp Creator icon${NC}"
  else
    echo -e "${YELLOW}ImageMagick not found, using fallback icon creation${NC}"
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
        echo -e "${YELLOW}Creating simple text icon${NC}"
        convert -size 128x128 xc:"#4A90E2" -font DejaVu-Sans-Bold -pointsize 16 \
          -fill white -gravity center -annotate +0+0 "WEBAPP\nCREATOR" \
          "$icon_path" 2>/dev/null
      fi
      
      # If convert fails or is not available, create a placeholder
      if [[ ! -f "$icon_path" ]]; then
        echo -e "${YELLOW}Creating placeholder icon${NC}"
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
  echo -e "${GREEN}✓ WebApp Creator desktop file created${NC}"
}

# Function to install webapp creator (moved from webapp-creator.sh)
install_webapp_creator() {
  show_header
  echo -e "${WHITE}Install WebApp Creator${NC}"
  echo -e "${WHITE}──────────────────────${NC}"
  echo

  # First check if Chromium is installed
  echo -e "${BLUE}Checking dependencies...${NC}"
  check_chromium
  echo

  local bin_dir="$HOME/.local/bin"
  local script_name="webapp-creator"
  local launcher_file="$LAUNCHER_DIR/launcher.sh"
  local gamemode_file="$LAUNCHER_DIR/game-mode.sh"
  local webapps_archive="$LAUNCHER_DIR/webapps.tar.gz"

  echo -e "${BLUE}Installing WebApp Creator...${NC}"

  # Create directories
  mkdir -p "$bin_dir"
  mkdir -p "$HOME/.local/share/applications"
  mkdir -p "$HOME/.local/share/icons/webapp-icons"
  mkdir -p "$HOME/.local/share/webapp-sync"
  echo -e "${GREEN}✓ Created necessary directories${NC}"

  # Copy webapp-creator script
  if [[ -f "$WEBAPP_CREATOR" ]]; then
    cp "$WEBAPP_CREATOR" "$bin_dir/$script_name"
    chmod +x "$bin_dir/$script_name"
    echo -e "${GREEN}✓ Copied script to: $bin_dir/$script_name${NC}"
  else
    echo -e "${RED}✗ WebApp Creator script not found: $WEBAPP_CREATOR${NC}"
    read -p "Press Enter to continue..." </dev/tty </dev/tty </dev/tty
    return 1
  fi

  # Copy additional scripts
  if [[ -f "$launcher_file" ]]; then
    cp "$launcher_file" "$bin_dir/"
    chmod +x "$bin_dir/launcher.sh"
    echo -e "${GREEN}✓ Copied launcher.sh${NC}"
  fi

  if [[ -f "$gamemode_file" ]]; then
    cp "$gamemode_file" "$bin_dir/"
    chmod +x "$bin_dir/game-mode.sh"
    echo -e "${GREEN}✓ Copied game-mode.sh${NC}"
  fi

  # Create WebApp Creator desktop entry
  create_webapp_creator_desktop

  # Import default webapps if archive exists
  if [[ -f "$webapps_archive" ]]; then
    echo -e "${BLUE}Importing default webapps...${NC}"

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
      echo -e "${GREEN}✓ Default icons imported${NC}"
    fi

    # Import applications
    if [[ -d "$temp_dir/applications" ]]; then
      cp "$temp_dir/applications/"*.desktop "$HOME/.local/share/applications/" 2>/dev/null
      echo -e "${GREEN}✓ Default applications imported${NC}"
    fi

    # Import config
    if [[ -f "$temp_dir/webapps.json" ]]; then
      cp "$temp_dir/webapps.json" "$HOME/.local/share/webapp-sync/"
      echo -e "${GREEN}✓ Default configuration imported${NC}"
    fi

    rm -rf "$temp_dir"
    echo -e "${GREEN}✓ Default webapps installed${NC}"
  fi

  # Check PATH
  if ! is_in_path "$bin_dir"; then
    echo
    echo -e "${YELLOW}⚠ Warning: $bin_dir is not in your PATH${NC}"
    echo -e "${BLUE}Add this line to your ~/.bashrc, ~/.zshrc, or ~/.config/fish/config.fish:${NC}"
    echo -e "${WHITE}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo -e "${YELLOW}For Fish shell: ${WHITE}fish_add_path ~/.local/bin${NC}"
  fi

  echo
  echo -e "${GREEN}✓ WebApp Creator installed successfully!${NC}"
  echo -e "${BLUE}You can now:${NC}"
  echo -e "${WHITE}  • Run 'webapp-creator' from terminal${NC}"
  echo -e "${WHITE}  • Find 'WebApp Creator' in your application menu${NC}"
  echo -e "${WHITE}  • Launch from rofi/launcher${NC}"

  read -p "Press Enter to continue..." </dev/tty </dev/tty
}

# Function to install everything automatically
install_all() {
  show_header
  echo -e "${WHITE}Instalación Completa Automática${NC}"
  echo -e "${WHITE}─────────────────────────────${NC}"
  echo

  echo -e "${BLUE}Este proceso instalará todo automáticamente:${NC}"
  echo -e "${WHITE}  1. AUR Helper${NC}"
  echo -e "${WHITE}  2. Paquetes del sistema${NC}"
  echo -e "${WHITE}  3. Configuraciones del sistema${NC}"
  echo -e "${WHITE}  4. WebApp Creator${NC}"
  echo
  echo -e "${YELLOW}¿Continuar con la instalación completa? (y/N):${NC} "
  read -r confirm_all </dev/tty

  if [[ ! "$confirm_all" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Instalación cancelada${NC}"
    read -p "Press Enter to continue..." </dev/tty </dev/tty </dev/tty
    return 1
  fi

  echo
  echo -e "${GREEN}Iniciando instalación completa...${NC}"
  echo

  # Step 1: Install AUR Helper
  echo -e "${BLUE}Paso 1/5: Instalando AUR Helper...${NC}"
  install_aur_silent

  # Step 2: Install packages
  echo -e "${BLUE}Paso 2/5: Instalando paquetes del sistema...${NC}"
  install_packages_silent

  # Step 3: Install configurations
  echo -e "${BLUE}Paso 3/5: Instalando configuraciones...${NC}"
  if [[ -f "$APPS_DIR/install_configs.sh" ]]; then
    echo "y" | "$APPS_DIR/install_configs.sh" "$REPO_DIR"
  else
    install_configs_silent
  fi

  # Step 4: Install WebApp Creator
  echo -e "${BLUE}Paso 4/5: Instalando WebApp Creator...${NC}"
  if [[ -f "$APPS_DIR/install_webapp.sh" ]]; then
    echo "y" | "$APPS_DIR/install_webapp.sh" "$REPO_DIR"
  else
    install_webapp_creator_silent
  fi

  # Step 5: Install SDDM (optional)
  echo -e "${BLUE}Paso 5/5: ¿Instalar SDDM theme? (y/N):${NC} "
  read -r install_sddm_choice </dev/tty
  if [[ "$install_sddm_choice" =~ ^[Yy]$ ]]; then
    if [[ -f "$APPS_DIR/install_sddm.sh" ]]; then
      "$APPS_DIR/install_sddm.sh"
    else
      echo -e "${YELLOW}Script SDDM no encontrado, saltando...${NC}"
    fi
  fi

  echo
  echo -e "${GREEN}✓ ¡Instalación completa finalizada!${NC}"
  echo -e "${BLUE}Debes reiniciar tu sesión para que todos los cambios tomen efecto${NC}"
  echo
  read -p "Press Enter to continue..." </dev/tty </dev/tty
}

# Silent installation functions for automated install
install_aur_silent() {
  local aur_script="$APPS_DIR/install_aur.sh"
  if [[ -f "$aur_script" ]]; then
    chmod +x "$aur_script"
    "$aur_script"
  else
    echo -e "${RED}✗ AUR installer not found: $aur_script${NC}"
    return 1
  fi
}

install_packages_silent() {
  local pkg_script="$APPS_DIR/install_pkg.sh"
  if [[ -f "$pkg_script" ]]; then
    chmod +x "$pkg_script"
    "$pkg_script"
  else
    echo -e "${RED}✗ Package installer not found: $pkg_script${NC}"
    return 1
  fi
}

install_configs_silent() {
  echo -e "${BLUE}Installing configuration files...${NC}"

  # Ensure we use the repository directory, not the script directory
  local source_dir="$REPO_DIR"
  echo -e "${BLUE}Using source directory: $source_dir${NC}"
  
  # Verify the repository directory exists and contains expected structure
  if [[ ! -d "$source_dir" ]]; then
    echo -e "${RED}✗ Repository directory not found: $source_dir${NC}"
    return 1
  fi
  
  if [[ ! -d "$source_dir/Apps" || ! -d "$source_dir/Launcher" ]]; then
    echo -e "${RED}✗ Invalid repository structure in: $source_dir${NC}"
    echo -e "${YELLOW}Expected: Apps/ and Launcher/ directories${NC}"
    return 1
  fi

  # Copy all directories except Apps and Launcher to ~/.config/
  for config_dir in "$source_dir"/*; do
    if [[ -d "$config_dir" ]]; then
      local dir_name=$(basename "$config_dir")

      # Skip Apps and Launcher directories
      if [[ "$dir_name" == "Apps" || "$dir_name" == "Launcher" ]]; then
        continue
      fi

      local target_dir="$HOME/.config/$dir_name"

      # Remove existing without backup for silent install
      if [[ -d "$target_dir" ]]; then
        rm -rf "$target_dir"
      fi

      # Copy configuration
      cp -r "$config_dir" "$target_dir"
      echo -e "${GREEN}  ✓ Installed $dir_name configuration${NC}"
    fi
  done
}

install_webapp_creator_silent() {
  # Check Chromium
  check_chromium

  local bin_dir="$HOME/.local/bin"
  local script_name="webapp-creator"

  # Create directories
  mkdir -p "$bin_dir"
  mkdir -p "$HOME/.local/share/applications"
  mkdir -p "$HOME/.local/share/icons/webapp-icons"
  mkdir -p "$HOME/.local/share/webapp-sync"

  # Copy webapp-creator script
  if [[ -f "$WEBAPP_CREATOR" ]]; then
    cp "$WEBAPP_CREATOR" "$bin_dir/$script_name"
    chmod +x "$bin_dir/$script_name"
    echo -e "${GREEN}✓ WebApp Creator installed${NC}"
  fi

  # Copy additional scripts
  if [[ -f "$LAUNCHER_SCRIPT" ]]; then
    cp "$LAUNCHER_SCRIPT" "$bin_dir/"
    chmod +x "$bin_dir/launcher.sh"
  fi

  if [[ -f "$GAMEMODE_SCRIPT" ]]; then
    cp "$GAMEMODE_SCRIPT" "$bin_dir/"
    chmod +x "$bin_dir/game-mode.sh"
  fi

  # Create desktop entry
  create_webapp_creator_desktop
}

# Function to copy to user directories
install_user() {
  echo -e "${BLUE}Installing to user directories...${NC}"

  # Create local bin directory
  mkdir -p "$LOCAL_BIN"

  # Copy webapp-creator to ~/.local/bin
  if [[ -f "$WEBAPP_CREATOR" ]]; then
    cp "$WEBAPP_CREATOR" "$LOCAL_BIN/webapp-creator"
    chmod +x "$LOCAL_BIN/webapp-creator"
    echo -e "${GREEN}✓ Copied webapp-creator to: $LOCAL_BIN/webapp-creator${NC}"
  else
    echo -e "${RED}✗ WebApp Creator script not found: $WEBAPP_CREATOR${NC}"
    return 1
  fi

  # Copy launcher if it exists
  if [[ -f "$LAUNCHER_SCRIPT" ]]; then
    cp "$LAUNCHER_SCRIPT" "$LOCAL_BIN/webapp-launcher"
    chmod +x "$LOCAL_BIN/webapp-launcher"
    echo -e "${GREEN}✓ Copied launcher to: $LOCAL_BIN/webapp-launcher${NC}"
  else
    echo -e "${YELLOW}! Launcher script not found, skipping...${NC}"
  fi

  # Copy game-mode script if it exists
  if [[ -f "$GAMEMODE_SCRIPT" ]]; then
    cp "$GAMEMODE_SCRIPT" "$LOCAL_BIN/webapp-gamemode"
    chmod +x "$LOCAL_BIN/webapp-gamemode"
    echo -e "${GREEN}✓ Copied game-mode to: $LOCAL_BIN/webapp-gamemode${NC}"
  else
    echo -e "${YELLOW}! Game-mode script not found, skipping...${NC}"
  fi

  # Create symlinks for easier access
  if [[ ! -L "$LOCAL_BIN/wac" ]]; then
    ln -s "$LOCAL_BIN/webapp-creator" "$LOCAL_BIN/wac"
    echo -e "${GREEN}✓ Created symlink: wac -> webapp-creator${NC}"
  fi

  if [[ -f "$LOCAL_BIN/webapp-gamemode" && ! -L "$LOCAL_BIN/wac-game" ]]; then
    ln -s "$LOCAL_BIN/webapp-gamemode" "$LOCAL_BIN/wac-game"
    echo -e "${GREEN}✓ Created symlink: wac-game -> webapp-gamemode${NC}"
  fi

  # Check PATH
  if ! is_in_path "$LOCAL_BIN"; then
    echo -e "${YELLOW}⚠ Warning: $LOCAL_BIN is not in your PATH${NC}"
    echo -e "${BLUE}Add this line to your ~/.bashrc, ~/.zshrc, or ~/.config/fish/config.fish:${NC}"
    echo -e "${WHITE}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo -e "${YELLOW}For Fish shell: ${WHITE}fish_add_path ~/.local/bin${NC}"
  fi

  echo -e "${GREEN}✓ User installation completed${NC}"
  return 0
}

# Function to set up development environment
setup_dev_environment() {
  echo -e "${BLUE}Setting up development environment...${NC}"

  # Make scripts executable in launcher directory
  if [[ -f "$WEBAPP_CREATOR" ]]; then
    chmod +x "$WEBAPP_CREATOR"
    echo -e "${GREEN}✓ Made webapp-creator executable${NC}"
  fi

  if [[ -f "$LAUNCHER_SCRIPT" ]]; then
    chmod +x "$LAUNCHER_SCRIPT"
    echo -e "${GREEN}✓ Made launcher.sh executable${NC}"
  fi

  if [[ -f "$GAMEMODE_SCRIPT" ]]; then
    chmod +x "$GAMEMODE_SCRIPT"
    echo -e "${GREEN}✓ Made game-mode.sh executable${NC}"
  fi

  # Make this script executable
  chmod +x "$0"
  echo -e "${GREEN}✓ Made install.sh executable${NC}"

  echo -e "${GREEN}✓ Development environment ready${NC}"
  echo -e "${BLUE}You can now run: ./Launcher/webapp-creator.sh${NC}"
  return 0
}

# Function to install system configurations
install_configs() {
  show_header
  echo -e "${WHITE}Install System Configurations${NC}"
  echo -e "${WHITE}─────────────────────────────${NC}"
  echo

  # Ask if user wants backups
  echo -e "${BLUE}This will copy all configuration directories to ~/.config/${NC}"
  echo -e "${YELLOW}Make backups of existing configurations? (y/N):${NC} "
  read -r make_backups </dev/tty
  echo

  echo -e "${BLUE}Installing configuration files...${NC}"

  # Ensure we use the repository directory, not the script directory
  local source_dir="$REPO_DIR"
  echo -e "${BLUE}Using source directory: $source_dir${NC}"
  
  # Verify the repository directory exists and contains expected structure
  if [[ ! -d "$source_dir" ]]; then
    echo -e "${RED}✗ Repository directory not found: $source_dir${NC}"
    read -p "Press Enter to continue..." </dev/tty
    return 1
  fi
  
  if [[ ! -d "$source_dir/Apps" || ! -d "$source_dir/Launcher" ]]; then
    echo -e "${RED}✗ Invalid repository structure in: $source_dir${NC}"
    echo -e "${YELLOW}Expected: Apps/ and Launcher/ directories${NC}"
    read -p "Press Enter to continue..." </dev/tty
    return 1
  fi

  local config_installed=0

  # Copy all directories except Apps and Launcher to ~/.config/
  for config_dir in "$source_dir"/*; do
    if [[ -d "$config_dir" ]]; then
      local dir_name=$(basename "$config_dir")

      # Skip Apps and Launcher directories
      if [[ "$dir_name" == "Apps" || "$dir_name" == "Launcher" ]]; then
        echo -e "${BLUE}Skipping: $dir_name${NC}"
        continue
      fi

      local target_dir="$HOME/.config/$dir_name"

      echo -e "${BLUE}Installing $dir_name configuration...${NC}"

      # Handle existing configurations
      if [[ -d "$target_dir" ]]; then
        if [[ "$make_backups" =~ ^[Yy]$ ]]; then
          # Create backup
          local backup_dir="$target_dir.backup.$(date +%Y%m%d_%H%M%S)"
          mv "$target_dir" "$backup_dir"
          echo -e "${YELLOW}  • Backed up existing config to: $(basename "$backup_dir")${NC}"
        else
          # Remove existing without backup
          rm -rf "$target_dir"
          echo -e "${YELLOW}  • Removed existing $dir_name config${NC}"
        fi
      fi

      # Copy configuration
      cp -r "$config_dir" "$target_dir"
      echo -e "${GREEN}  ✓ Installed $dir_name configuration${NC}"
      config_installed=1
    fi
  done

  if [[ $config_installed -eq 1 ]]; then
    echo
    echo -e "${GREEN}✓ System configurations installed successfully!${NC}"
    echo -e "${BLUE}Configurations copied to ~/.config/${NC}"
    echo -e "${YELLOW}Note: You may need to restart your session for changes to take effect${NC}"
  else
    echo -e "${YELLOW}No configuration directories found to install${NC}"
  fi

  echo
  read -p "Press Enter to continue..." </dev/tty </dev/tty
}

# Function to install AUR helper
install_aur() {
  show_header
  echo -e "${WHITE}Install AUR Helper${NC}"
  echo -e "${WHITE}──────────────────${NC}"
  echo

  local aur_script="$APPS_DIR/install_aur.sh"

  if [[ -f "$aur_script" ]]; then
    echo -e "${BLUE}Running AUR installer...${NC}"
    echo
    chmod +x "$aur_script"
    "$aur_script"
  else
    echo -e "${RED}✗ AUR installer not found: $aur_script${NC}"
    echo -e "${BLUE}Make sure the file exists in the Apps directory${NC}"
  fi

  echo
  read -p "Press Enter to continue..." </dev/tty </dev/tty
}

# Function to install packages
install_packages() {
  show_header
  echo -e "${WHITE}Install Packages${NC}"
  echo -e "${WHITE}────────────────${NC}"
  echo

  local pkg_script="$APPS_DIR/install_pkg.sh"

  if [[ -f "$pkg_script" ]]; then
    echo -e "${BLUE}Running package installer...${NC}"
    echo
    chmod +x "$pkg_script"
    "$pkg_script"

    # Check if fish was installed and offer to change shell
    if command -v fish &>/dev/null; then
      echo
      echo -e "${GREEN}✓ Fish shell detected${NC}"
      
      # Check if fish is already the default shell
      local current_shell=$(getent passwd "$USER" | cut -d: -f7)
      if [[ "$current_shell" == "/usr/bin/fish" ]]; then
        echo -e "${GREEN}✓ Fish ya es tu shell predeterminado${NC}"
      else
        echo -e "${BLUE}Shell actual: $current_shell${NC}"
        echo -e "${BLUE}Would you like to change your default shell to fish?${NC}"
        echo -ne "${YELLOW}Change to fish shell? (y/N): ${NC}"
        read -r fish_choice </dev/tty

        if [[ "$fish_choice" =~ ^[Yy]$ ]]; then
          echo -e "${BLUE}Changing default shell to fish...${NC}"
          if chsh -s /usr/bin/fish; then
            echo -e "${GREEN}✓ Default shell changed to fish${NC}"
            echo -e "${BLUE}Please log out and log back in for changes to take effect${NC}"
          else
            echo -e "${RED}✗ Failed to change shell to fish${NC}"
            echo -e "${YELLOW}You can change it manually with: chsh -s /usr/bin/fish${NC}"
          fi
        else
          echo -e "${BLUE}Keeping current shell${NC}"
        fi
      fi
    fi
  else
    echo -e "${RED}✗ Package installer not found: $pkg_script${NC}"
    echo -e "${BLUE}Make sure the file exists in the Apps directory${NC}"
  fi

  echo
  read -p "Press Enter to continue..." </dev/tty </dev/tty
}

# Function to run WebApp Creator + Configs installation
install_webapp_and_configs() {
  show_header
  echo -e "${WHITE}WebApp Creator + System Configurations${NC}"
  echo -e "${WHITE}────────────────────────────────────────${NC}"
  echo
  
  echo -e "${BLUE}Este proceso instalará:${NC}"
  echo -e "${WHITE}  1. WebApp Creator y dependencias${NC}"
  echo -e "${WHITE}  2. Configuraciones del sistema${NC}"
  echo
  echo -e "${YELLOW}¿Continuar? (y/N):${NC} "
  read -r confirm </dev/tty
  
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Instalación cancelada${NC}"
    read -p "Press Enter to continue..." </dev/tty
    return 1
  fi
  
  echo
  echo -e "${GREEN}Iniciando instalación combinada...${NC}"
  echo
  
  # Run WebApp Creator installer
  echo -e "${BLUE}Paso 1/2: Instalando WebApp Creator...${NC}"
  if [[ -f "$APPS_DIR/install_webapp.sh" ]]; then
    "$APPS_DIR/install_webapp.sh" "$REPO_DIR"
  else
    echo -e "${RED}✗ Script install_webapp.sh no encontrado${NC}"
    read -p "Press Enter to continue..." </dev/tty
    return 1
  fi
  
  echo
  echo -e "${BLUE}Paso 2/2: Instalando configuraciones del sistema...${NC}"
  if [[ -f "$APPS_DIR/install_configs.sh" ]]; then
    "$APPS_DIR/install_configs.sh" "$REPO_DIR"
  else
    echo -e "${RED}✗ Script install_configs.sh no encontrado${NC}"
    read -p "Press Enter to continue..." </dev/tty
    return 1
  fi
  
  echo
  echo -e "${GREEN}✓ Instalación completa finalizada!${NC}"
  read -p "Press Enter to continue..." </dev/tty
}

# Function to run SDDM installer
install_sddm() {
  if [[ -f "$APPS_DIR/install_sddm.sh" ]]; then
    "$APPS_DIR/install_sddm.sh"
  else
    echo -e "${RED}✗ Script install_sddm.sh no encontrado${NC}"
    read -p "Press Enter to continue..." </dev/tty
  fi
}

# Function to run Plymouth installer
install_plymouth() {
  if [[ -f "$APPS_DIR/install_plymouth.sh" ]]; then
    "$APPS_DIR/install_plymouth.sh" "$REPO_DIR"
  else
    echo -e "${RED}✗ Script install_plymouth.sh no encontrado${NC}"
    read -p "Press Enter to continue..." </dev/tty
  fi
}

# Function to uninstall everything
uninstall() {
  echo -e "${YELLOW}Uninstalling WebApp Creator and configurations...${NC}"

  # Remove from user directories
  if [[ -f "$LOCAL_BIN/webapp-creator" ]]; then
    rm -f "$LOCAL_BIN/webapp-creator"
    echo -e "${GREEN}✓ Removed from: $LOCAL_BIN/webapp-creator${NC}"
  fi

  if [[ -f "$LOCAL_BIN/webapp-launcher" ]]; then
    rm -f "$LOCAL_BIN/webapp-launcher"
    echo -e "${GREEN}✓ Removed from: $LOCAL_BIN/webapp-launcher${NC}"
  fi

  if [[ -f "$LOCAL_BIN/webapp-gamemode" ]]; then
    rm -f "$LOCAL_BIN/webapp-gamemode"
    echo -e "${GREEN}✓ Removed from: $LOCAL_BIN/webapp-gamemode${NC}"
  fi

  if [[ -L "$LOCAL_BIN/wac" ]]; then
    rm -f "$LOCAL_BIN/wac"
    echo -e "${GREEN}✓ Removed symlink: $LOCAL_BIN/wac${NC}"
  fi

  if [[ -L "$LOCAL_BIN/wac-game" ]]; then
    rm -f "$LOCAL_BIN/wac-game"
    echo -e "${GREEN}✓ Removed symlink: $LOCAL_BIN/wac-game${NC}"
  fi

  # Remove WebApp Creator data
  if [[ -d "$HOME/.local/share/webapp-sync" ]]; then
    rm -rf "$HOME/.local/share/webapp-sync"
    echo -e "${GREEN}✓ Removed WebApp Creator data${NC}"
  fi

  if [[ -d "$HOME/.local/share/icons/webapp-icons" ]]; then
    rm -rf "$HOME/.local/share/icons/webapp-icons"
    echo -e "${GREEN}✓ Removed WebApp Creator icons${NC}"
  fi

  echo -e "${GREEN}✓ Uninstallation completed${NC}"
  echo -e "${BLUE}Note: System configurations in ~/.config/ were not removed${NC}"
}

# Function to show status with Gum
show_status() {
  echo
  if [[ "$HAS_GUM" == true ]]; then
    gum style --foreground "#87CEEB" --bold "Estado Actual:"
  else
    echo -e "${WHITE}Current Status:${NC}"
  fi
  
  if [[ -f "$LOCAL_BIN/webapp-creator" ]]; then
    if [[ "$HAS_GUM" == true ]]; then
      gum style --foreground "#90EE90" "  ✓ User installation found"
    else
      echo -e "${GREEN}  ✓ User installation found${NC}"
    fi
  else
    if [[ "$HAS_GUM" == true ]]; then
      gum style --foreground "#FFD700" "  ○ No user installation"
    else
      echo -e "${YELLOW}  ○ No user installation${NC}"
    fi
  fi

  if [[ -d "$HOME/.config/i3" && -d "$HOME/.config/polybar" ]]; then
    if [[ "$HAS_GUM" == true ]]; then
      gum style --foreground "#90EE90" "  ✓ System configurations installed"
    else
      echo -e "${GREEN}  ✓ System configurations installed${NC}"
    fi
  else
    if [[ "$HAS_GUM" == true ]]; then
      gum style --foreground "#FFD700" "  ○ No system configurations"
    else
      echo -e "${YELLOW}  ○ No system configurations${NC}"
    fi
  fi
  echo
}

# Main menu with Gum support
main_menu() {
  while true; do
    show_header

    # Check availability of options based on directory structure
    local launcher_available=true
    local apps_available=true

    if [[ ! -d "$LAUNCHER_DIR" ]]; then
      launcher_available=false
    fi

    if [[ ! -d "$APPS_DIR" ]]; then
      apps_available=false
    fi

    # Build menu options array
    local options=()
    
    # Option 1
    if [[ "$launcher_available" == true && "$apps_available" == true ]]; then
      options+=("Instalación Completa Automática - Instala todo de una vez")
    else
      options+=("[DESHABILITADO] Instalación Completa Automática - Faltan directorios")
    fi

    # Option 2
    if [[ "$launcher_available" == true ]]; then
      options+=("Install WebApp Creator + System Configs - Complete setup")
    else
      options+=("[DESHABILITADO] Install WebApp Creator + Configs - Falta directorio Launcher")
    fi

    # Option 3
    if [[ "$apps_available" == true ]]; then
      options+=("Install AUR Helper")
    else
      options+=("[DESHABILITADO] Install AUR Helper - Falta directorio Apps")
    fi

    # Option 4
    if [[ "$apps_available" == true ]]; then
      options+=("Install Packages")
    else
      options+=("[DESHABILITADO] Install Packages - Falta directorio Apps")
    fi

    # Option 5
    if [[ "$apps_available" == true ]]; then
      options+=("Install SDDM Theme (Corners) - Login manager setup")
    else
      options+=("[DESHABILITADO] Install SDDM Theme - Falta directorio Apps")
    fi

    # Option 6
    if [[ "$apps_available" == true ]]; then
      options+=("Install Plymouth Themes - Boot splash themes")
    else
      options+=("[DESHABILITADO] Install Plymouth Themes - Falta directorio Apps")
    fi

    # Options 7 and 8
    options+=("Uninstall - Remove all installations")
    options+=("Exit")

    # Show status
    show_status

    # Use Gum if available, otherwise fallback to classic menu
    local choice_index
    if [[ "$HAS_GUM" == true ]]; then
      # Try to use Gum - it can work even without TTY in some cases
      local selected
      selected=$(printf '%s\n' "${options[@]}" | gum choose --header "🛠️  Opciones de Instalación" --height 12 2>/dev/null)
      
      if [[ -n "$selected" ]]; then
        # Find index of selected option
        for i in "${!options[@]}"; do
          if [[ "${options[$i]}" == "$selected" ]]; then
            choice_index=$((i + 1))
            break
          fi
        done
      elif [[ -c /dev/tty ]]; then
        # If Gum failed but TTY is available, try again with TTY
        selected=$(printf '%s\n' "${options[@]}" | gum choose --header "🛠️  Opciones de Instalación" --height 12 </dev/tty)
        if [[ -n "$selected" ]]; then
          for i in "${!options[@]}"; do
            if [[ "${options[$i]}" == "$selected" ]]; then
              choice_index=$((i + 1))
              break
            fi
          done
        else
          echo -e "${BLUE}Operación cancelada${NC}"
          exit 0
        fi
      else
        # No TTY available and Gum failed - fall back to classic menu
        HAS_GUM=false
      fi
    fi
    
    # If we still don't have a choice (fallback to classic menu)
    if [[ -z "$choice_index" ]]; then
      echo -e "${WHITE}Installation Options${NC}"
      echo -e "${WHITE}───────────────────${NC}"
      echo
      
      for i in "${!options[@]}"; do
        local option_num=$((i + 1))
        if [[ "${options[$i]}" =~ ^\[DESHABILITADO\] ]]; then
          echo -e "${RED}$option_num.${NC} ${RED}${options[$i]#[DESHABILITADO] }${NC}"
        else
          echo -e "${CYAN}$option_num.${NC} ${options[$i]}"
        fi
      done
      echo
      
      # Try to read from TTY if available
      if [[ -c /dev/tty ]]; then
        printf "${YELLOW}Select option (1-8): ${NC}"
        read -r choice_index </dev/tty
      else
        # No TTY available - try to read from stdin
        printf "${YELLOW}Select option (1-8): ${NC}"
        read -r choice_index
        
        # If still no input, show error and exit
        if [[ -z "$choice_index" ]]; then
          echo
          echo -e "${RED}Error: No se puede leer entrada del usuario${NC}"
          echo -e "${YELLOW}Ejecuta el script en modo interactivo o instala Gum para mejor compatibilidad${NC}"
          echo -e "${BLUE}Ejemplo: bash <(curl -fsSL tu-url)${NC}"
          exit 1
        fi
      fi
    fi

    case $choice_index in
    1)
      if [[ "$launcher_available" == true && "$apps_available" == true ]]; then
        install_all
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Faltan directorios requeridos.${NC}"
        echo
        read -p "Press Enter to continue..." </dev/tty
      fi
      ;;
    2)
      if [[ "$launcher_available" == true ]]; then
        install_webapp_and_configs
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Launcher.${NC}"
        echo
        read -p "Press Enter to continue..." </dev/tty
      fi
      ;;
    3)
      if [[ "$apps_available" == true ]]; then
        install_aur
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..." </dev/tty
      fi
      ;;
    4)
      if [[ "$apps_available" == true ]]; then
        install_packages
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..." </dev/tty
      fi
      ;;
    5)
      if [[ "$apps_available" == true ]]; then
        install_sddm
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..." </dev/tty
      fi
      ;;
    6)
      if [[ "$apps_available" == true ]]; then
        install_plymouth
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..." </dev/tty
      fi
      ;;
    7)
      echo
      echo -e "${YELLOW}Are you sure you want to uninstall? (y/N)${NC}"
      read -r confirm </dev/tty
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        uninstall
      else
        echo -e "${BLUE}Uninstall cancelled${NC}"
      fi
      echo
      read -p "Press Enter to continue..." </dev/tty
      ;;
    8)
      echo -e "${GREEN}Goodbye!${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid option${NC}"
      ;;
    esac
  done
}

# Initialize environment
detect_environment

# Clone repository if running standalone
clone_repository

# Check and install Gum for better UI
HAS_GUM=false
if check_install_gum; then
  HAS_GUM=true
fi

# Check if required directories exist after potential cloning
if [[ ! -d "$LAUNCHER_DIR" ]]; then
  show_header
  echo -e "${YELLOW}⚠ Launcher directory not found: $LAUNCHER_DIR${NC}"
  echo -e "${BLUE}Expected structure:${NC}"
  echo -e "${WHITE}  $REPO_NAME/${NC}"
  echo -e "${WHITE}  ├── install.sh${NC}"
  echo -e "${WHITE}  ├── Launcher/        ${YELLOW}(webapp-creator files)${NC}"
  echo -e "${WHITE}  ├── Apps/            ${YELLOW}(installer scripts)${NC}"
  echo -e "${WHITE}  ├── i3/              ${YELLOW}(config directories)${NC}"
  echo -e "${WHITE}  └── polybar/         ${YELLOW}(to copy to ~/.config/)${NC}"
  echo
  echo -e "${BLUE}Algunas opciones pueden no estar disponibles sin estos directorios.${NC}"
  echo -e "${YELLOW}Continuando con las opciones disponibles...${NC}"
  echo

  if [[ "$IS_STANDALONE" == true ]]; then
    echo -e "${YELLOW}Si el problema persiste, verifica la URL del repositorio${NC}"
    echo -e "${BLUE}URL actual: $REPO_URL${NC}"
    echo
  fi
fi

# Start the application
main_menu
