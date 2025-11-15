#!/usr/bin/env bash

# Install Script for WebApp Creator and System Configuration
# This script installs webapp-creator and system configurations
# Can be run directly via curl or from cloned repository

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
Exec=$install_script --update
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

      # Skip Apps, Launcher, Wallpapers, and chromium directories
      if [[ "$dir_name" == "Apps" || "$dir_name" == "Launcher" || "$dir_name" == "Wallpapers" || "$dir_name" == "chromium" ]]; then
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

# Function to run Icons installer
install_icons() {
  show_header
  echo -e "${WHITE}Install Icon Themes${NC}"
  echo -e "${WHITE}───────────────────${NC}"
  echo
  
  if [[ -f "$APPS_DIR/install_icons.sh" ]]; then
    echo -e "${BLUE}Running icon themes installer...${NC}"
    echo
    chmod +x "$APPS_DIR/install_icons.sh"
    "$APPS_DIR/install_icons.sh" "$REPO_DIR"
  else
    echo -e "${RED}✗ Icon installer not found: $APPS_DIR/install_icons.sh${NC}"
    echo -e "${BLUE}Make sure the file exists in the Apps directory${NC}"
  fi
  
  echo
  read -p "Press Enter to continue..." </dev/tty
}

# Function to run Google Cloud CLI installer
install_gcloud() {
  show_header
  echo -e "${WHITE}Install Google Cloud CLI${NC}"
  echo -e "${WHITE}────────────────────────${NC}"
  echo
  
  if [[ -f "$APPS_DIR/install_gcloud.sh" ]]; then
    echo -e "${BLUE}Running Google Cloud CLI installer...${NC}"
    echo
    chmod +x "$APPS_DIR/install_gcloud.sh"
    "$APPS_DIR/install_gcloud.sh"
  else
    echo -e "${RED}✗ Google Cloud CLI installer not found: $APPS_DIR/install_gcloud.sh${NC}"
    echo -e "${BLUE}Make sure the file exists in the Apps directory${NC}"
  fi
  
  echo
  read -p "Press Enter to continue..." </dev/tty
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

# Function to run Starship installer
install_starship() {
  show_header
  echo -e "${WHITE}Install Starship Configuration${NC}"
  echo -e "${WHITE}─────────────────────────────${NC}"
  echo
  
  if [[ -f "$APPS_DIR/install_starship.sh" ]]; then
    echo -e "${BLUE}Running Starship installer...${NC}"
    echo
    chmod +x "$APPS_DIR/install_starship.sh"
    "$APPS_DIR/install_starship.sh"
  else
    echo -e "${RED}✗ Starship installer not found: $APPS_DIR/install_starship.sh${NC}"
    echo -e "${BLUE}Make sure the file exists in the Apps directory${NC}"
  fi
  
  echo
  read -p "Press Enter to continue..." </dev/tty
}

# Function to run Chaotic-AUR installer
install_chaotic() {
  show_header
  echo -e "${WHITE}Install Chaotic-AUR Repository${NC}"
  echo -e "${WHITE}──────────────────────────────${NC}"
  echo
  
  if [[ -f "$APPS_DIR/install_chaotic.sh" ]]; then
    echo -e "${BLUE}Running Chaotic-AUR installer...${NC}"
    echo
    chmod +x "$APPS_DIR/install_chaotic.sh"
    "$APPS_DIR/install_chaotic.sh"
  else
    echo -e "${RED}✗ Chaotic-AUR installer not found: $APPS_DIR/install_chaotic.sh${NC}"
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
    
    # Option 1 - System Configurations
    if [[ "$apps_available" == true ]]; then
      options+=("Install System Configurations - i3, polybar, fish, etc.")
    else
      options+=("[DESHABILITADO] Install System Configurations - Falta directorio Apps")
    fi

    # Option 2 - Wallpapers
    if [[ "$wallpapers_available" == true ]]; then
      options+=("Setup Wallpapers - Configure backgrounds for i3WM")
    else
      options+=("[DESHABILITADO] Setup Wallpapers - Falta directorio Wallpapers")
    fi

    # Option 3 - WebApp Creator
    if [[ "$launcher_available" == true ]]; then
      options+=("Install WebApp Creator - Create web applications")
    else
      options+=("[DESHABILITADO] Install WebApp Creator - Falta directorio Launcher")
    fi

    # Option 4 - AUR Helper
    if [[ "$apps_available" == true ]]; then
      options+=("Install AUR Helper")
    else
      options+=("[DESHABILITADO] Install AUR Helper - Falta directorio Apps")
    fi

    # Option 5 - Packages
    if [[ "$apps_available" == true ]]; then
      options+=("Install Packages")
    else
      options+=("[DESHABILITADO] Install Packages - Falta directorio Apps")
    fi

    # Option 6 - Chaotic-AUR
    if [[ "$apps_available" == true ]]; then
      options+=("Install Chaotic-AUR Repository - Add chaotic-aur and multilib")
    else
      options+=("[DESHABILITADO] Install Chaotic-AUR - Falta directorio Apps")
    fi

    # Option 7 - Starship Configuration
    if [[ "$apps_available" == true ]]; then
      options+=("Install Starship Configuration - Terminal prompt theme")
    else
      options+=("[DESHABILITADO] Install Starship Configuration - Falta directorio Apps")
    fi

    # Option 8 - npm Packages
    if [[ "$apps_available" == true ]]; then
      options+=("Install npm Packages - Claude CLI y herramientas npm")
    else
      options+=("[DESHABILITADO] Install npm Packages - Falta directorio Apps")
    fi

    # Option 9 - Flatpak
    if [[ "$apps_available" == true ]]; then
      options+=("Install Flatpak Apps - Aplicaciones desde Flathub")
    else
      options+=("[DESHABILITADO] Install Flatpak Apps - Falta directorio Apps")
    fi

    # Option 10 - Printer System
    if [[ "$apps_available" == true ]]; then
      options+=("Install Printer System - CUPS, drivers and configuration")
    else
      options+=("[DESHABILITADO] Install Printer System - Falta directorio Apps")
    fi

    # Option 11 - SDDM
    if [[ "$apps_available" == true ]]; then
      options+=("Install SDDM Theme - Login manager setup")
    else
      options+=("[DESHABILITADO] Install SDDM Theme - Falta directorio Apps")
    fi

    # Option 12 - Plymouth
    if [[ "$apps_available" == true ]]; then
      options+=("Install Plymouth Themes - Boot splash themes")
    else
      options+=("[DESHABILITADO] Install Plymouth Themes - Falta directorio Apps")
    fi

    # Option 13 - System76
    if [[ "$apps_available" == true ]]; then
      options+=("Install System76 Power - Power management tools")
    else
      options+=("[DESHABILITADO] Install System76 Power - Falta directorio Apps")
    fi

    # Option 14 - Icon Themes
    if [[ "$apps_available" == true ]]; then
      options+=("Install Icon Themes - Install icon themes to system")
    else
      options+=("[DESHABILITADO] Install Icon Themes - Falta directorio Apps")
    fi

    # Option 15 - Google Cloud CLI
    if [[ "$apps_available" == true ]]; then
      options+=("Install Google Cloud CLI - Install and configure gcloud")
    else
      options+=("[DESHABILITADO] Install Google Cloud CLI - Falta directorio Apps")
    fi

    # Option 16 - ORGMOS WebApp Creator
    options+=("ORGMOS WebApp Creator - Create web applications")
    
    # Option 17 - ORGMOS Display Manager
    options+=("ORGMOS Display Manager - Manage screen configurations")
    
    # Option 18 - ORGMOS Wallpaper Selector
    options+=("ORGMOS Wallpaper Selector - Change wallpapers")
    
    # Option 19 - ORGMOS Gestor de Paquetes
    options+=("ORGMOS Gestor de Paquetes - Package manager")
    
    # Option 20 - ORGMOS Modo Juego
    options+=("ORGMOS Modo Juego - Toggle game mode")
    
    # Option 21 - ORGMOS Desktop Apps
    options+=("ORGMOS Desktop Apps - Open applications directory")

    # Options 22 and 23
    options+=("Uninstall - Remove all installations")
    options+=("Exit")

    # Show status
    show_status

    # Use Gum if available, otherwise fallback to classic menu
    local choice_index
    if [[ "$HAS_GUM" == true ]]; then
      # Use Gum for interactive selection
      local selected
      selected=$(printf '%s\n' "${options[@]}" | gum choose --header "🛠️  Opciones de Instalación" --height 23)
      
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
      
      printf "Select option (1-23): "
      read -r choice_index
      
      if [[ -z "$choice_index" ]]; then
        echo "Error: No se puede leer entrada del usuario"
        exit 1
      fi
    fi

    case $choice_index in
    1)
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
    2)
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
        install_chaotic
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
        install_starship
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
    9)
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
    10)
      if [[ "$apps_available" == true ]]; then
        install_printer
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    11)
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
    12)
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
    13)
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
    14)
      if [[ "$apps_available" == true ]]; then
        install_icons
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    15)
      if [[ "$apps_available" == true ]]; then
        install_gcloud
        echo
        read -p "Press Enter to continue..."
      else
        echo
        echo -e "${RED}Esta opción no está disponible. Falta el directorio Apps.${NC}"
        echo
        read -p "Press Enter to continue..."
      fi
      ;;
    16)
      run_webapp_creator
      ;;
    17)
      run_display_manager
      ;;
    18)
      run_wallpaper_selector
      ;;
    19)
      run_orgmos_pacman
      ;;
    20)
      run_game_mode
      ;;
    21)
      run_desktop_apps
      ;;
    22)
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
    23)
      echo -e "${GREEN}¡Hasta luego!${NC}"
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

# Function to run ORGMOS WebApp Creator
run_webapp_creator() {
  show_header
  echo -e "${WHITE}ORGMOS WebApp Creator${NC}"
  echo -e "${WHITE}────────────────────${NC}"
  echo
  
  if [[ -f "$HOME/.local/bin/webapp-creator" ]]; then
    echo -e "${BLUE}Ejecutando WebApp Creator...${NC}"
    "$HOME/.local/bin/webapp-creator"
  else
    echo -e "${RED}✗ WebApp Creator no está instalado${NC}"
    echo -e "${YELLOW}Instala primero el WebApp Creator desde el menú principal${NC}"
  fi
  
  echo
  read -p "Press Enter to continue..." </dev/tty
}

# Function to run ORGMOS Display Manager
run_display_manager() {
  show_header
  echo -e "${WHITE}ORGMOS Display Manager${NC}"
  echo -e "${WHITE}──────────────────────${NC}"
  echo
  
  if [[ -f "$HOME/.config/i3/scripts/display-manager.sh" ]]; then
    echo -e "${BLUE}Ejecutando Display Manager...${NC}"
    if command -v kitty &>/dev/null; then
      kitty -e "$HOME/.config/i3/scripts/display-manager.sh"
    else
      echo -e "${YELLOW}Kitty no está disponible, ejecutando en terminal actual...${NC}"
      "$HOME/.config/i3/scripts/display-manager.sh"
    fi
  else
    echo -e "${RED}✗ Display Manager no está instalado${NC}"
    echo -e "${YELLOW}Instala primero las configuraciones del sistema desde el menú principal${NC}"
  fi
  
  echo
  read -p "Press Enter to continue..." </dev/tty
}

# Function to run ORGMOS Wallpaper Selector
run_wallpaper_selector() {
  show_header
  echo -e "${WHITE}ORGMOS Wallpaper Selector${NC}"
  echo -e "${WHITE}─────────────────────────${NC}"
  echo
  
  if [[ -f "$HOME/.config/i3/scripts/wallpaper-selector.sh" ]]; then
    echo -e "${BLUE}Ejecutando Wallpaper Selector...${NC}"
    "$HOME/.config/i3/scripts/wallpaper-selector.sh"
  else
    echo -e "${RED}✗ Wallpaper Selector no está instalado${NC}"
    echo -e "${YELLOW}Instala primero las configuraciones del sistema desde el menú principal${NC}"
  fi
  
  echo
  read -p "Press Enter to continue..." </dev/tty
}

# Function to run ORGMOS Gestor de Paquetes
run_orgmos_pacman() {
  show_header
  echo -e "${WHITE}ORGMOS Gestor de Paquetes${NC}"
  echo -e "${WHITE}────────────────────────${NC}"
  echo
  
  if [[ -f "$HOME/.local/bin/orgmos_pacman" ]]; then
    echo -e "${BLUE}Ejecutando Gestor de Paquetes...${NC}"
    "$HOME/.local/bin/orgmos_pacman"
  else
    echo -e "${RED}✗ Gestor de Paquetes no está instalado${NC}"
    echo -e "${YELLOW}Instala primero las configuraciones del sistema desde el menú principal${NC}"
  fi
  
  echo
  read -p "Press Enter to continue..." </dev/tty
}

# Function to run ORGMOS Modo Juego
run_game_mode() {
  show_header
  echo -e "${WHITE}ORGMOS Modo Juego${NC}"
  echo -e "${WHITE}─────────────────${NC}"
  echo
  
  if [[ -f "$HOME/.config/i3/scripts/game-mode.sh" ]]; then
    echo -e "${BLUE}Ejecutando Modo Juego...${NC}"
    # Ejecutar sin terminal - el script maneja la ejecución en background
    "$HOME/.config/i3/scripts/game-mode.sh"
  else
    echo -e "${RED}✗ Modo Juego no está instalado${NC}"
    echo -e "${YELLOW}Instala primero las configuraciones del sistema desde el menú principal${NC}"
  fi
  
  echo
  read -p "Press Enter to continue..." </dev/tty
}

# Function to run ORGMOS Desktop Apps
run_desktop_apps() {
  show_header
  echo -e "${WHITE}ORGMOS Desktop Apps${NC}"
  echo -e "${WHITE}───────────────────${NC}"
  echo
  
  if command -v xdg-open &>/dev/null; then
    echo -e "${BLUE}Abriendo directorio de aplicaciones...${NC}"
    xdg-open "$HOME/.local/share/applications"
  else
    echo -e "${RED}✗ xdg-open no está disponible${NC}"
    echo -e "${YELLOW}Instala xdg-utils para abrir el directorio${NC}"
  fi
  
  echo
  read -p "Press Enter to continue..." </dev/tty
}

echo
echo -e "${BLUE}Presiona Enter para continuar al menú principal...${NC}"
read -r </dev/tty

# Start the application
main_menu
