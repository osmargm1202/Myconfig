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
    echo -e "${GREEN}✓ Gum está instalado${NC}"
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
  GAMEMODE_SCRIPT="$REPO_DIR/i3/scripts/game-mode.sh"
  SYSTEM_BIN="/usr/local/bin"
  LOCAL_BIN="$HOME/.local/bin"
}

# Function to setup ORGMOS desktop application
setup_orgmos_desktop() {
  local desktop_dir="$HOME/.local/share/applications"
  local icon_dir="$HOME/.local/share/icons"
  local desktop_file="$desktop_dir/orgmos.desktop"
  local icon_file="$icon_dir/orgmos.png"
  local install_script="$REPO_DIR/install.sh"
  
  # Create directories if they don't exist
  mkdir -p "$desktop_dir"
  mkdir -p "$icon_dir"
  
  # Download icon if not present
  if [[ ! -f "$icon_file" ]]; then
    echo -e "${BLUE}Descargando icono de ORGMOS...${NC}"
    if command -v curl &>/dev/null; then
      if curl -s -L "https://r2.or-gm.com/orgm.png" -o "$icon_file"; then
        echo -e "${GREEN}✓ Icono descargado exitosamente${NC}"
      else
        echo -e "${YELLOW}⚠ No se pudo descargar el icono${NC}"
      fi
    elif command -v wget &>/dev/null; then
      if wget -q "https://r2.or-gm.com/orgm.png" -O "$icon_file"; then
        echo -e "${GREEN}✓ Icono descargado exitosamente${NC}"
      else
        echo -e "${YELLOW}⚠ No se pudo descargar el icono${NC}"
      fi
    else
      echo -e "${YELLOW}⚠ curl/wget no disponibles, saltando descarga de icono${NC}"
    fi
  fi
  
  # Create or update .desktop file
  echo -e "${BLUE}Configurando aplicación ORGMOS...${NC}"
  cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=ORGMOS
Comment=ORGMOS System Configuration Installer
Exec=$install_script
Icon=orgmos
Categories=System;Settings;
Terminal=true
NoDisplay=false
StartupNotify=true
EOF
  
  # Make desktop file executable
  chmod +x "$desktop_file"
  
  # Update desktop database
  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$desktop_dir" 2>/dev/null
  fi
  
  echo -e "${GREEN}✓ Aplicación ORGMOS configurada${NC}"
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
  echo "========================================"
  echo "      System & WebApp Installer         "
  echo "        Complete Setup Tool             "
  echo "========================================"
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



# Function to install everything automatically
install_all() {
  show_header
  echo -e "${WHITE}Instalación Completa Automática${NC}"
  echo -e "${WHITE}─────────────────────────────${NC}"
  echo

  echo -e "${BLUE}Este proceso instalará todo automáticamente:${NC}"
  echo -e "${WHITE}  1. AUR Helper${NC}"
  echo -e "${WHITE}  2. Paquetes del sistema${NC}"
  echo -e "${WHITE}  3. Paquetes npm (Claude CLI, etc.)${NC}"
  echo -e "${WHITE}  4. Aplicaciones Flatpak${NC}"
  echo -e "${WHITE}  5. Configuraciones del sistema${NC}"
  echo -e "${WHITE}  6. WebApp Creator${NC}"
  echo -e "${WHITE}  7. SDDM Theme${NC}"
  echo -e "${WHITE}  8. Plymouth Themes${NC}"
  echo -e "${WHITE}  9. Wallpapers${NC}"
  echo -e "${WHITE}  10. System76 Power${NC}"
  echo -e "${WHITE}  11. Printer System${NC}"
  echo -e "${WHITE}  12. Finalización y verificación${NC}"
  echo
  echo -e "${BLUE}Iniciando instalación completa automática...${NC}"
  echo

  # Step 1: Install AUR Helper
  echo -e "${BLUE}Paso 1/12: Instalando AUR Helper...${NC}"
  install_aur_silent

  # Step 2: Install packages
  echo -e "${BLUE}Paso 2/12: Instalando paquetes del sistema...${NC}"
  install_packages_silent

  # Step 3: Install npm packages
  echo -e "${BLUE}Paso 3/12: Instalando paquetes npm...${NC}"
  install_npm_silent

  # Step 4: Install Flatpak apps
  echo -e "${BLUE}Paso 4/12: Instalando aplicaciones Flatpak...${NC}"
  install_flatpak_silent

  # Step 5: Install configurations
  echo -e "${BLUE}Paso 5/12: Instalando configuraciones...${NC}"
  if [[ -f "$APPS_DIR/install_configs.sh" ]]; then
    echo "y" | "$APPS_DIR/install_configs.sh" "$REPO_DIR"
  else
    install_configs_silent
  fi

  # Step 6: Install WebApp Creator
  echo -e "${BLUE}Paso 6/12: Instalando WebApp Creator...${NC}"
  if [[ -f "$APPS_DIR/install_webapp.sh" ]]; then
    echo "y" | "$APPS_DIR/install_webapp.sh" "$REPO_DIR"
  else
    install_webapp_creator_silent
  fi

  # Step 7: Install SDDM
  echo -e "${BLUE}Paso 7/12: Instalando SDDM Theme...${NC}"
  install_sddm_silent

  # Step 8: Install Plymouth
  echo -e "${BLUE}Paso 8/12: Instalando Plymouth Themes...${NC}"
  install_plymouth_silent

  # Step 9: Install Wallpapers
  echo -e "${BLUE}Paso 9/12: Instalando Wallpapers...${NC}"
  install_wallpapers_silent

  # Step 10: Install System76 Power
  echo -e "${BLUE}Paso 10/12: Instalando System76 Power...${NC}"
  install_system76_silent

  # Step 11: Install Printer System
  echo -e "${BLUE}Paso 11/12: Instalando Printer System...${NC}"
  install_printer_silent

  # Step 12: Finalization and verification
  echo -e "${BLUE}Paso 12/12: Finalización y verificación...${NC}"
  
  # Verify key components
  echo -e "${CYAN}Verificando instalaciones...${NC}"
  
  # Check AUR helper
  if command -v yay &>/dev/null || command -v paru &>/dev/null; then
    echo -e "${GREEN}  ✓ AUR Helper instalado${NC}"
  else
    echo -e "${YELLOW}  ⚠ AUR Helper no encontrado${NC}"
  fi
  
  # Check configurations
  if [[ -d "$HOME/.config/i3" && -d "$HOME/.config/polybar" ]]; then
    echo -e "${GREEN}  ✓ Configuraciones del sistema instaladas${NC}"
  else
    echo -e "${YELLOW}  ⚠ Configuraciones del sistema incompletas${NC}"
  fi
  
  # Check WebApp Creator
  if [[ -f "$HOME/.local/bin/webapp-creator" ]]; then
    echo -e "${GREEN}  ✓ WebApp Creator instalado${NC}"
  else
    echo -e "${YELLOW}  ⚠ WebApp Creator no encontrado${NC}"
  fi
  
  # Check wallpapers
  if [[ -d "$HOME/Wallpapers" ]]; then
    echo -e "${GREEN}  ✓ Wallpapers instalados${NC}"
  else
    echo -e "${YELLOW}  ⚠ Wallpapers no encontrados${NC}"
  fi

  echo
  echo -e "${GREEN}✓ ¡Instalación completa finalizada!${NC}"
  echo -e "${BLUE}Debes reiniciar tu sesión para que todos los cambios tomen efecto${NC}"
  echo
  read -p "Press Enter to continue..." </dev/tty </dev/tty
}

# Silent installation functions for missing components
install_plymouth_silent() {
  local plymouth_script="$APPS_DIR/install_plymouth.sh"
  if [[ -f "$plymouth_script" ]]; then
    chmod +x "$plymouth_script"
    "$plymouth_script" "$REPO_DIR"
  else
    echo -e "${YELLOW}⚠ Plymouth installer not found, skipping...${NC}"
  fi
}

install_wallpapers_silent() {
  local wallpapers_script="$APPS_DIR/install_wallpapers.sh"
  if [[ -f "$wallpapers_script" ]]; then
    chmod +x "$wallpapers_script"
    "$wallpapers_script" "$REPO_DIR"
  else
    echo -e "${YELLOW}⚠ Wallpapers installer not found, skipping...${NC}"
  fi
}

install_system76_silent() {
  local system76_script="$APPS_DIR/install_system76.sh"
  if [[ -f "$system76_script" ]]; then
    chmod +x "$system76_script"
    "$system76_script"
  else
    echo -e "${YELLOW}⚠ System76 installer not found, skipping...${NC}"
  fi
}

install_printer_silent() {
  local printer_script="$APPS_DIR/install_printer.sh"
  if [[ -f "$printer_script" ]]; then
    chmod +x "$printer_script"
    "$printer_script"
  else
    echo -e "${YELLOW}⚠ Printer installer not found, skipping...${NC}"
  fi
}

install_sddm_silent() {
  local sddm_script="$APPS_DIR/install_sddm.sh"
  if [[ -f "$sddm_script" ]]; then
    chmod +x "$sddm_script"
    "$sddm_script"
  else
    echo -e "${YELLOW}⚠ SDDM installer not found, skipping...${NC}"
  fi
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

install_flatpak_silent() {
  local flatpak_script="$APPS_DIR/install_flatpak.sh"
  if [[ -f "$flatpak_script" ]]; then
    chmod +x "$flatpak_script"
    "$flatpak_script"
  else
    echo -e "${RED}✗ Flatpak installer not found: $flatpak_script${NC}"
    return 1
  fi
}

install_npm_silent() {
  local npm_script="$APPS_DIR/install_npm.sh"
  if [[ -f "$npm_script" ]]; then
    chmod +x "$npm_script"
    "$npm_script"
  else
    echo -e "${YELLOW}⚠ npm installer not found: $npm_script${NC}"
    echo -e "${BLUE}Skipping npm packages installation...${NC}"
    return 0
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

      # Skip Apps, Launcher, and Wallpapers directories
      if [[ "$dir_name" == "Apps" || "$dir_name" == "Launcher" || "$dir_name" == "Wallpapers" ]]; then
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
    # Also give permissions to i3 scripts
    if [[ -d "$REPO_DIR/i3/scripts" ]]; then
      chmod +x "$REPO_DIR/i3/scripts"/*.sh 2>/dev/null
    fi
  fi

  # Create desktop entry (simplified)
  local apps_dir="$HOME/.local/share/applications"
  local desktop_file="$apps_dir/webapp-creator.desktop"
  local bin_path="$HOME/.local/bin/webapp-creator"

  mkdir -p "$apps_dir"
  
  cat >"$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=WebApp Creator
Comment=Create and manage web applications using Chromium
Exec=$bin_path
Categories=Development;System;Utility;
NoDisplay=false
StartupNotify=true
Terminal=true
EOF

  chmod +x "$desktop_file"
  echo -e "${GREEN}✓ WebApp Creator desktop file created${NC}"
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

      # Skip Apps, Launcher, and Wallpapers directories
      if [[ "$dir_name" == "Apps" || "$dir_name" == "Launcher" || "$dir_name" == "Wallpapers" ]]; then
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

# Function to run Wallpapers installer
install_wallpapers() {
  if [[ -f "$APPS_DIR/install_wallpapers.sh" ]]; then
    "$APPS_DIR/install_wallpapers.sh" "$REPO_DIR"
  else
    echo -e "${RED}✗ Script install_wallpapers.sh no encontrado${NC}"
    read -p "Press Enter to continue..." </dev/tty
  fi
}

# Function to run System76 Power installer
install_system76() {
  if [[ -f "$APPS_DIR/install_system76.sh" ]]; then
    "$APPS_DIR/install_system76.sh"
  else
    echo -e "${RED}✗ Script install_system76.sh no encontrado${NC}"
    read -p "Press Enter to continue..." </dev/tty
  fi
}

# Function to run Printer installer
install_printer() {
  show_header
  echo -e "${WHITE}Install Printer System${NC}"
  echo -e "${WHITE}─────────────────────${NC}"
  echo
  
  if [[ -f "$APPS_DIR/install_printer.sh" ]]; then
    echo -e "${BLUE}Running printer installer...${NC}"
    echo
    chmod +x "$APPS_DIR/install_printer.sh"
    "$APPS_DIR/install_printer.sh"
  else
    echo -e "${RED}✗ Printer installer not found: $APPS_DIR/install_printer.sh${NC}"
    echo -e "${BLUE}Make sure the file exists in the Apps directory${NC}"
  fi
  
  echo
  read -p "Press Enter to continue..." </dev/tty
}

# Function to run Flatpak installer
install_flatpak() {
  show_header
  echo -e "${WHITE}Install Flatpak Applications${NC}"
  echo -e "${WHITE}────────────────────────────${NC}"
  echo
  
  if [[ -f "$APPS_DIR/install_flatpak.sh" ]]; then
    echo -e "${BLUE}Running Flatpak installer...${NC}"
    echo
    chmod +x "$APPS_DIR/install_flatpak.sh"
    "$APPS_DIR/install_flatpak.sh"
  else
    echo -e "${RED}✗ Flatpak installer not found: $APPS_DIR/install_flatpak.sh${NC}"
    echo -e "${BLUE}Make sure the file exists in the Apps directory${NC}"
  fi
  
  echo
  read -p "Press Enter to continue..." </dev/tty
}

# Function to run npm installer
install_npm() {
  show_header
  echo -e "${WHITE}Install npm Packages${NC}"
  echo -e "${WHITE}────────────────────${NC}"
  echo
  
  if [[ -f "$APPS_DIR/install_npm.sh" ]]; then
    echo -e "${BLUE}Running npm installer...${NC}"
    echo
    chmod +x "$APPS_DIR/install_npm.sh"
    "$APPS_DIR/install_npm.sh"
  else
    echo -e "${RED}✗ npm installer not found: $APPS_DIR/install_npm.sh${NC}"
    echo -e "${BLUE}Make sure the file exists in the Apps directory${NC}"
  fi
  
  echo
  read -p "Press Enter to continue..." </dev/tty
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

# Function to show status (simple, no Gum issues)
show_status() {
  echo
  echo "Estado Actual:"
  
  if [[ -f "$LOCAL_BIN/webapp-creator" ]]; then
    echo "  ✓ User installation found"
  else
    echo "  ○ No user installation"
  fi

  if [[ -d "$HOME/.config/i3" && -d "$HOME/.config/polybar" ]]; then
    echo "  ✓ System configurations installed"
  else
    echo "  ○ No system configurations"
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
    local wallpapers_available=true

    if [[ ! -d "$LAUNCHER_DIR" ]]; then
      launcher_available=false
    fi

    if [[ ! -d "$APPS_DIR" ]]; then
      apps_available=false
    fi

    if [[ ! -d "$REPO_DIR/Wallpapers" ]]; then
      wallpapers_available=false
    fi

    # Build menu options array
    local options=()
    
    # Option 1
    if [[ "$launcher_available" == true && "$apps_available" == true ]]; then
      options+=("Instalación Completa Automática - Instala todo de una vez")
    else
      options+=("[DESHABILITADO] Instalación Completa Automática - Faltan directorios")
    fi

    # Option 2 - System Configurations only
    if [[ "$apps_available" == true ]]; then
      options+=("Install System Configurations - i3, polybar, fish, etc.")
    else
      options+=("[DESHABILITADO] Install System Configurations - Falta directorio Apps")
    fi

    # Option 3 - WebApp Creator only
    if [[ "$launcher_available" == true ]]; then
      options+=("Install WebApp Creator - Create web applications")
    else
      options+=("[DESHABILITADO] Install WebApp Creator - Falta directorio Launcher")
    fi

    # Option 4
    if [[ "$apps_available" == true ]]; then
      options+=("Install AUR Helper")
    else
      options+=("[DESHABILITADO] Install AUR Helper - Falta directorio Apps")
    fi

    # Option 5
    if [[ "$apps_available" == true ]]; then
      options+=("Install Packages")
    else
      options+=("[DESHABILITADO] Install Packages - Falta directorio Apps")
    fi

    # Option 6
    if [[ "$apps_available" == true ]]; then
      options+=("Install npm Packages - Claude CLI y herramientas npm")
    else
      options+=("[DESHABILITADO] Install npm Packages - Falta directorio Apps")
    fi

    # Option 7
    if [[ "$apps_available" == true ]]; then
      options+=("Install Flatpak Apps - Aplicaciones desde Flathub")
    else
      options+=("[DESHABILITADO] Install Flatpak Apps - Falta directorio Apps")
    fi

    # Option 8
    if [[ "$apps_available" == true ]]; then
      options+=("Install SDDM Theme (Corners) - Login manager setup")
    else
      options+=("[DESHABILITADO] Install SDDM Theme - Falta directorio Apps")
    fi

    # Option 9
    if [[ "$apps_available" == true ]]; then
      options+=("Install Plymouth Themes - Boot splash themes")
    else
      options+=("[DESHABILITADO] Install Plymouth Themes - Falta directorio Apps")
    fi

    # Option 10 - Wallpapers
    if [[ "$wallpapers_available" == true ]]; then
      options+=("Setup Wallpapers - Configure backgrounds for i3WM")
    else
      options+=("[DESHABILITADO] Setup Wallpapers - Falta directorio Wallpapers")
    fi

    # Option 11 - System76 Power
    if [[ "$apps_available" == true ]]; then
      options+=("Install System76 Power - Power management tools")
    else
      options+=("[DESHABILITADO] Install System76 Power - Falta directorio Apps")
    fi

    # Option 12 - Printer System
    if [[ "$apps_available" == true ]]; then
      options+=("Install Printer System - CUPS, drivers and configuration")
    else
      options+=("[DESHABILITADO] Install Printer System - Falta directorio Apps")
    fi

    # Options 13 and 14
    options+=("Uninstall - Remove all installations")
    options+=("Exit")

    # Show status
    show_status

    # Use Gum if available, otherwise fallback to classic menu
    local choice_index
    if [[ "$HAS_GUM" == true ]]; then
      # Use Gum for interactive selection
      local selected
      selected=$(printf '%s\n' "${options[@]}" | gum choose --header "🛠️  Opciones de Instalación" --height 15)
      
      if [[ -n "$selected" ]]; then
        # Find index of selected option
        for i in "${!options[@]}"; do
          if [[ "${options[$i]}" == "$selected" ]]; then
            choice_index=$((i + 1))
            break
          fi
        done
      else
        echo "No se seleccionó ninguna opción"
        continue
      fi
    else
      # Fallback to classic menu
      echo
      echo "Installation Options"
      echo "==================="
      echo
      
      for i in "${!options[@]}"; do
        local option_num=$((i + 1))
        if [[ "${options[$i]}" =~ ^\[DESHABILITADO\] ]]; then
          echo "$option_num. [DISABLED] ${options[$i]#[DESHABILITADO] }"
        else
          echo "$option_num. ${options[$i]}"
        fi
      done
      echo
      
      printf "Select option (1-14): "
      read -r choice_index
      
      if [[ -z "$choice_index" ]]; then
        echo "Error: No se puede leer entrada del usuario"
        exit 1
      fi
    fi

    case $choice_index in
    1)
      if [[ "$launcher_available" == true && "$apps_available" == true ]]; then
        install_all
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Faltan directorios requeridos.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    2)
      if [[ "$apps_available" == true ]]; then
        install_configs_auto
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    3)
      if [[ "$launcher_available" == true ]]; then
        install_webapp_auto
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Launcher.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    4)
      if [[ "$apps_available" == true ]]; then
        install_aur
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    5)
      if [[ "$apps_available" == true ]]; then
        install_packages
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    6)
      if [[ "$apps_available" == true ]]; then
        install_npm
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    7)
      if [[ "$apps_available" == true ]]; then
        install_flatpak
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    8)
      if [[ "$apps_available" == true ]]; then
        install_sddm
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    9)
      if [[ "$apps_available" == true ]]; then
        install_plymouth
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    10)
      if [[ "$wallpapers_available" == true ]]; then
        install_wallpapers
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Wallpapers.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    11)
      if [[ "$apps_available" == true ]]; then
        install_system76
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    12)
      if [[ "$apps_available" == true ]]; then
        install_printer
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    13)
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
    14)
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

# Setup ORGMOS desktop application
setup_orgmos_desktop

# Check Gum availability and offer to install
HAS_GUM=false
if command -v gum &>/dev/null; then
  HAS_GUM=true
  # Set Gum colors
  export GUM_CHOOSE_SELECTED_FOREGROUND="#87CEEB"  # Sky Blue
  export GUM_CHOOSE_CURSOR_FOREGROUND="#00BFFF"    # Deep Sky Blue
  export GUM_CONFIRM_SELECTED_FOREGROUND="#87CEEB"
  export GUM_INPUT_CURSOR_FOREGROUND="#00BFFF"
  export GUM_INPUT_PROMPT_FOREGROUND="#87CEEB"
  export GUM_FILTER_INDICATOR_FOREGROUND="#00BFFF"
  export GUM_FILTER_MATCH_FOREGROUND="#87CEEB"
  echo -e "${GREEN}✓ Gum está instalado${NC}"
else
  echo -e "${YELLOW}⚠ Gum no está instalado${NC}"
  echo -e "${BLUE}Gum es necesario para una mejor experiencia de usuario${NC}"
  echo -e "${YELLOW}¿Instalar Gum ahora? (y/N):${NC} "
  read -r install_gum </dev/tty
  
  if [[ "$install_gum" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Instalando Gum...${NC}"
    if sudo pacman -S gum --noconfirm; then
      echo -e "${GREEN}✓ Gum instalado exitosamente${NC}"
      HAS_GUM=true
      # Set Gum colors
      export GUM_CHOOSE_SELECTED_FOREGROUND="#87CEEB"
      export GUM_CHOOSE_CURSOR_FOREGROUND="#00BFFF"
      export GUM_CONFIRM_SELECTED_FOREGROUND="#87CEEB"
      export GUM_INPUT_CURSOR_FOREGROUND="#00BFFF"
      export GUM_INPUT_PROMPT_FOREGROUND="#87CEEB"
      export GUM_FILTER_INDICATOR_FOREGROUND="#00BFFF"
      export GUM_FILTER_MATCH_FOREGROUND="#87CEEB"
    else
      echo -e "${RED}✗ Error al instalar Gum${NC}"
      echo -e "${YELLOW}Continuando sin Gum (funcionalidad básica)${NC}"
    fi
  else
    echo -e "${YELLOW}Continuando sin Gum (funcionalidad básica)${NC}"
  fi
  echo
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

# Show project path verification
echo -e "${BLUE}📁 Directorio del proyecto: $REPO_DIR${NC}"
echo -e "${BLUE}🔍 Verificando estructura...${NC}"

if [[ -d "$LAUNCHER_DIR" ]]; then
  echo -e "${GREEN}  ✓ Launcher/ encontrado${NC}"
else
  echo -e "${RED}  ✗ Launcher/ no encontrado${NC}"
fi

if [[ -d "$APPS_DIR" ]]; then
  echo -e "${GREEN}  ✓ Apps/ encontrado${NC}"
else
  echo -e "${RED}  ✗ Apps/ no encontrado${NC}"
fi

if [[ -d "$REPO_DIR/Wallpapers" ]]; then
  echo -e "${GREEN}  ✓ Wallpapers/ encontrado${NC}"
else
  echo -e "${RED}  ✗ Wallpapers/ no encontrado${NC}"
fi

# Function to install system configurations automatically (no confirmations)
install_configs_auto() {
  show_header
  echo -e "${WHITE}Instalando Configuraciones del Sistema${NC}"
  echo -e "${WHITE}─────────────────────────────────────${NC}"
  echo

  echo -e "${BLUE}Instalando configuraciones automáticamente...${NC}"
  echo -e "${YELLOW}Las configuraciones existentes serán reemplazadas sin backup${NC}"
  echo

  # Use the install_configs.sh script with automatic mode
  if [[ -f "$APPS_DIR/install_configs.sh" ]]; then
    echo "n" | "$APPS_DIR/install_configs.sh" "$REPO_DIR"
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✓ Configuraciones instaladas exitosamente${NC}"
    else
      echo -e "${RED}✗ Error en la instalación de configuraciones${NC}"
      return 1
    fi
  else
    echo -e "${RED}✗ Script install_configs.sh no encontrado${NC}"
    return 1
  fi

  echo
  echo -e "${GREEN}✓ Instalación de configuraciones completada${NC}"
}

# Function to install webapp creator automatically (no confirmations)
install_webapp_auto() {
  show_header
  echo -e "${WHITE}Instalando WebApp Creator${NC}"
  echo -e "${WHITE}─────────────────────────${NC}"
  echo

  echo -e "${BLUE}Instalando WebApp Creator automáticamente...${NC}"
  echo -e "${YELLOW}Las instalaciones existentes serán reemplazadas sin backup${NC}"
  echo

  # Use the new install_webapp.sh script from Launcher
  if [[ -f "$LAUNCHER_DIR/install_webapp.sh" ]]; then
    "$LAUNCHER_DIR/install_webapp.sh" "$REPO_DIR"
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✓ WebApp Creator instalado exitosamente${NC}"
    else
      echo -e "${RED}✗ Error en la instalación de WebApp Creator${NC}"
      return 1
    fi
  else
    echo -e "${RED}✗ Script install_webapp.sh no encontrado en Launcher/${NC}"
    return 1
  fi

  echo
  echo -e "${GREEN}✓ Instalación de WebApp Creator completada${NC}"
}

echo
echo -e "${BLUE}Presiona Enter para continuar al menú principal...${NC}"
read -r </dev/tty

# Start the application
main_menu
