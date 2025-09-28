#!/bin/bash

# Install Script for WebApp Creator and System Configuration
# This script installs webapp-creator and system configurations
# Can be run directly via curl or from cloned repository

# Repository information
REPO_URL="https://github.com/osmar/Myconfig.git"  # Replace with your actual repository URL
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

# Function to detect if we're in repository or standalone
detect_environment() {
  SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

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
      echo -e "${BLUE}¿Quieres actualizarlo? (y/N):${NC} "
      read -r update_repo

      if [[ "$update_repo" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Actualizando repositorio...${NC}"
        cd "$REPO_DIR" && git pull
        if [[ $? -eq 0 ]]; then
          echo -e "${GREEN}✓ Repositorio actualizado${NC}"
        else
          echo -e "${RED}✗ Error al actualizar repositorio${NC}"
          exit 1
        fi
      fi
    else
      # Clone repository
      echo -e "${BLUE}Clonando repositorio desde: $REPO_URL${NC}"

      if command -v git &>/dev/null; then
        git clone "$REPO_URL" "$REPO_DIR"
        if [[ $? -eq 0 ]]; then
          echo -e "${GREEN}✓ Repositorio clonado exitosamente${NC}"
        else
          echo -e "${RED}✗ Error al clonar repositorio${NC}"
          echo -e "${YELLOW}Asegúrate de que git esté instalado y la URL sea correcta${NC}"
          exit 1
        fi
      else
        echo -e "${RED}✗ Git no está instalado${NC}"
        echo -e "${BLUE}Instalando git...${NC}"

        if command -v pacman &>/dev/null; then
          sudo pacman -S git --noconfirm
        elif command -v apt &>/dev/null; then
          sudo apt update && sudo apt install -y git
        elif command -v yum &>/dev/null; then
          sudo yum install -y git
        else
          echo -e "${RED}✗ No se pudo instalar git automáticamente${NC}"
          echo -e "${BLUE}Por favor instala git manualmente y vuelve a ejecutar el script${NC}"
          exit 1
        fi

        # Try cloning again after installing git
        git clone "$REPO_URL" "$REPO_DIR"
        if [[ $? -eq 0 ]]; then
          echo -e "${GREEN}✓ Repositorio clonado exitosamente${NC}"
        else
          echo -e "${RED}✗ Error al clonar repositorio${NC}"
          exit 1
        fi
      fi
    fi

    echo
    echo -e "${GREEN}✓ Repositorio listo en: $REPO_DIR${NC}"
    echo
    sleep 2
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
    read -r install_choice

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
      echo -e "${YELLOW}Creating simple text icon${NC}"
      convert -size 128x128 xc:"#4A90E2" -font DejaVu-Sans-Bold -pointsize 16 \
        -fill white -gravity center -annotate +0+0 "WEBAPP\nCREATOR" \
        "$icon_path" 2>/dev/null || {
        # If convert fails completely, create a placeholder
        touch "$icon_path"
      }
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
    read -p "Press Enter to continue..."
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

    local temp_dir=$(mktemp -d)
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
  if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
    echo
    echo -e "${YELLOW}⚠ Warning: $bin_dir is not in your PATH${NC}"
    echo -e "${BLUE}Add this line to your ~/.bashrc or ~/.zshrc:${NC}"
    echo -e "${WHITE}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
  fi

  echo
  echo -e "${GREEN}✓ WebApp Creator installed successfully!${NC}"
  echo -e "${BLUE}You can now:${NC}"
  echo -e "${WHITE}  • Run 'webapp-creator' from terminal${NC}"
  echo -e "${WHITE}  • Find 'WebApp Creator' in your application menu${NC}"
  echo -e "${WHITE}  • Launch from rofi/launcher${NC}"

  read -p "Press Enter to continue..."
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
  read -r confirm_all

  if [[ ! "$confirm_all" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Instalación cancelada${NC}"
    read -p "Press Enter to continue..."
    return 1
  fi

  echo
  echo -e "${GREEN}Iniciando instalación completa...${NC}"
  echo

  # Step 1: Install AUR Helper
  echo -e "${BLUE}Paso 1/4: Instalando AUR Helper...${NC}"
  install_aur_silent

  # Step 2: Install packages
  echo -e "${BLUE}Paso 2/4: Instalando paquetes del sistema...${NC}"
  install_packages_silent

  # Step 3: Install configurations
  echo -e "${BLUE}Paso 3/4: Instalando configuraciones...${NC}"
  install_configs_silent

  # Step 4: Install WebApp Creator
  echo -e "${BLUE}Paso 4/4: Instalando WebApp Creator...${NC}"
  install_webapp_creator_silent

  echo
  echo -e "${GREEN}✓ ¡Instalación completa finalizada!${NC}"
  echo -e "${BLUE}Debes reiniciar tu sesión para que todos los cambios tomen efecto${NC}"
  echo
  read -p "Press Enter to continue..."
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

  # Copy all directories except Apps and Launcher to ~/.config/
  for config_dir in "$SCRIPT_DIR"/*; do
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
  if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo -e "${YELLOW}⚠ Warning: $LOCAL_BIN is not in your PATH${NC}"
    echo -e "${BLUE}Add this line to your ~/.bashrc or ~/.zshrc:${NC}"
    echo -e "${WHITE}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
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
  read -r make_backups
  echo

  echo -e "${BLUE}Installing configuration files...${NC}"

  # Check if we're in the right directory structure
  if [[ ! -d "$SCRIPT_DIR" ]]; then
    echo -e "${RED}✗ Configuration directory not found: $SCRIPT_DIR${NC}"
    read -p "Press Enter to continue..."
    return 1
  fi

  local config_installed=0

  # Copy all directories except Apps and Launcher to ~/.config/
  for config_dir in "$SCRIPT_DIR"/*; do
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
  read -p "Press Enter to continue..."
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
  read -p "Press Enter to continue..."
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
      echo -e "${BLUE}Would you like to change your default shell to fish?${NC}"
      echo -ne "${YELLOW}Change to fish shell? (y/N): ${NC}"
      read -r fish_choice

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
  else
    echo -e "${RED}✗ Package installer not found: $pkg_script${NC}"
    echo -e "${BLUE}Make sure the file exists in the Apps directory${NC}"
  fi

  echo
  read -p "Press Enter to continue..."
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

# Main menu
main_menu() {
  while true; do
    show_header

    echo -e "${WHITE}Installation Options${NC}"
    echo -e "${WHITE}───────────────────${NC}"
    echo
    echo -e "${CYAN}1.${NC} Instalación Completa Automática - Instala todo de una vez"
    echo -e "${CYAN}2.${NC} Install WebApp Creator (User) - Current user only"
    echo -e "${CYAN}3.${NC} Development Setup - Make scripts executable"
    echo -e "${CYAN}4.${NC} Install System Configurations - Copy configs to ~/.config/"
    echo -e "${CYAN}5.${NC} Install AUR Helper"
    echo -e "${CYAN}6.${NC} Install Packages"
    echo -e "${CYAN}7.${NC} Uninstall - Remove all installations"
    echo -e "${CYAN}8.${NC} Exit"
    echo

    # Show current installations
    echo -e "${WHITE}Current Status:${NC}"
    if [[ -f "$LOCAL_BIN/webapp-creator" ]]; then
      echo -e "${GREEN}  ✓ User installation found${NC}"
    else
      echo -e "${YELLOW}  ○ No user installation${NC}"
    fi

    if [[ -d "$HOME/.config/i3" && -d "$HOME/.config/polybar" ]]; then
      echo -e "${GREEN}  ✓ System configurations installed${NC}"
    else
      echo -e "${YELLOW}  ○ No system configurations${NC}"
    fi
    echo

    echo -ne "${YELLOW}Select option (1-8): ${NC}"
    read -r choice

    case $choice in
    1)
      install_all
      ;;
    2)
      echo
      install_webapp_creator
      ;;
    3)
      echo
      setup_dev_environment
      echo
      read -p "Press Enter to continue..."
      ;;
    4)
      install_configs
      ;;
    5)
      install_aur
      ;;
    6)
      install_packages
      ;;
    7)
      echo
      echo -e "${YELLOW}Are you sure you want to uninstall? (y/N)${NC}"
      read -r confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        uninstall
      else
        echo -e "${BLUE}Uninstall cancelled${NC}"
      fi
      echo
      read -p "Press Enter to continue..."
      ;;
    8)
      echo -e "${GREEN}Goodbye!${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid option${NC}"
      sleep 1
      ;;
    esac
  done
}

# Initialize environment
detect_environment

# Clone repository if running standalone
clone_repository

# Check if required directories exist after potential cloning
if [[ ! -d "$LAUNCHER_DIR" ]]; then
  show_header
  echo -e "${RED}✗ Launcher directory not found: $LAUNCHER_DIR${NC}"
  echo -e "${BLUE}Expected structure:${NC}"
  echo -e "${WHITE}  $REPO_NAME/${NC}"
  echo -e "${WHITE}  ├── install.sh${NC}"
  echo -e "${WHITE}  ├── Launcher/        ${YELLOW}(webapp-creator files)${NC}"
  echo -e "${WHITE}  ├── Apps/            ${YELLOW}(installer scripts)${NC}"
  echo -e "${WHITE}  ├── i3/              ${YELLOW}(config directories)${NC}"
  echo -e "${WHITE}  └── polybar/         ${YELLOW}(to copy to ~/.config/)${NC}"

  if [[ "$IS_STANDALONE" == true ]]; then
    echo
    echo -e "${YELLOW}Si el problema persiste, verifica la URL del repositorio${NC}"
    echo -e "${BLUE}URL actual: $REPO_URL${NC}"
  fi
  exit 1
fi

# Start the application
main_menu
