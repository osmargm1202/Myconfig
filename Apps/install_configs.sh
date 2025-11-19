#!/usr/bin/env bash

# System Configurations Installer
# Installs system configuration files to ~/.config/

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
  echo -e "${CYAN}║     System Configuration Installer    ║${NC}"
  echo -e "${CYAN}║       Copy configs to ~/.config/      ║${NC}"
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
  
  if [[ ! -d "$source_dir/Apps" || ! -d "$source_dir/Launcher" ]]; then
    echo -e "${RED}✗ Estructura de repositorio inválida en: $source_dir${NC}"
    echo -e "${YELLOW}Se esperan directorios: Apps/ y Launcher/${NC}"
    return 1
  fi
  
  return 0
}

# Function to list available configurations
list_configurations() {
  local source_dir="$1"
  local configs=()
  
  for config_dir in "$source_dir"/*; do
    if [[ -d "$config_dir" ]]; then
      local dir_name=$(basename "$config_dir")
      
      # Skip Apps, Launcher, sddm, Wallpapers, Icons, and chromium directories
      if [[ "$dir_name" == "Apps" || "$dir_name" == "Launcher" || "$dir_name" == "sddm" || "$dir_name" == "Wallpapers" || "$dir_name" == "Icons" || "$dir_name" == "chromium" ]]; then
        continue
      fi
      
      configs+=("$dir_name")
    fi
  done
  
  printf '%s\n' "${configs[@]}"
}

# Function to show configuration details
show_config_details() {
  local source_dir="$1"
  local configs=("$@")
  
  echo -e "${WHITE}Configuraciones a instalar:${NC}"
  echo
  
  for config in "${configs[@]:1}"; do
    local config_path="$source_dir/$config"
    local file_count=$(find "$config_path" -type f 2>/dev/null | wc -l)
    local target_path="$HOME/.config/$config"
    local status=""
    
    if [[ -d "$target_path" ]]; then
      status="${YELLOW}(será reemplazada)${NC}"
    else
      status="${GREEN}(nueva)${NC}"
    fi
    
    echo -e "${CYAN}  • $config${NC} $status - $file_count archivos"
  done
  
  echo
  echo -e "${YELLOW}Nota: Las configuraciones existentes serán reemplazadas sin backup${NC}"
  echo
}

# Function to backup existing configurations
backup_configuration() {
  local config_name="$1"
  local target_dir="$HOME/.config/$config_name"
  
  if [[ -d "$target_dir" ]]; then
    local backup_dir="$target_dir.backup.$(date +%Y%m%d_%H%M%S)"
    if mv "$target_dir" "$backup_dir"; then
      echo -e "${YELLOW}  • Backup creado: $(basename "$backup_dir")${NC}"
      return 0
    else
      echo -e "${RED}  • Error al crear backup${NC}"
      return 1
    fi
  fi
  
  return 0
}

# Function to install single configuration
install_single_config() {
  local source_dir="$1"
  local config_name="$2"
  local make_backup="$3"
  
  local source_path="$source_dir/$config_name"
  local target_path="$HOME/.config/$config_name"
  
  echo -e "${BLUE}Instalando configuración: $config_name${NC}"
  
  # Handle existing configuration
  if [[ -d "$target_path" ]]; then
    if [[ "$make_backup" == "true" ]]; then
      if ! backup_configuration "$config_name"; then
        return 1
      fi
    else
      echo -e "${YELLOW}  • Removiendo configuración existente${NC}"
      rm -rf "$target_path"
    fi
  fi
  
  # Copy new configuration (force overwrite all files)
  if cp -rf "$source_path" "$target_path"; then
    local file_count=$(find "$target_path" -type f | wc -l)
    
    # Give execute permissions to all scripts (overwrite existing permissions)
    local script_count=0
    while IFS= read -r script_file; do
      chmod +x "$script_file" 2>/dev/null
      ((script_count++))
    done < <(find "$target_path" -name "*.sh" -type f 2>/dev/null)
    
    # Special handling for autorandr hook
    if [[ "$config_name" == "i3" ]]; then
      local autorandr_hook="$target_path/scripts/autorandr-hook.sh"
      if [[ -f "$autorandr_hook" ]]; then
        chmod +x "$autorandr_hook"
        # Create symlink in autorandr hooks directory
        mkdir -p "$HOME/.config/autorandr/postswitch.d"
        ln -sf "$autorandr_hook" "$HOME/.config/autorandr/postswitch.d/auto-display-handler" 2>/dev/null
        echo -e "${BLUE}  ✓ Hook de autorandr configurado${NC}"
      fi
    fi
    
    echo -e "${GREEN}  ✓ Instalado $config_name ($file_count archivos)${NC}"
    if [[ $script_count -gt 0 ]]; then
      echo -e "${BLUE}  ✓ Permisos de ejecución otorgados a $script_count script(s) .sh${NC}"
    fi
    
    # Verify all source scripts were copied
    local source_scripts=()
    while IFS= read -r script; do
      [[ -n "$script" ]] && source_scripts+=("$script")
    done < <(find "$source_path" -name "*.sh" -type f 2>/dev/null)
    
    local missing_scripts=()
    for source_script in "${source_scripts[@]}"; do
      local rel_path="${source_script#$source_path/}"
      local target_script="$target_path/$rel_path"
      if [[ ! -f "$target_script" ]]; then
        missing_scripts+=("$rel_path")
      fi
    done
    
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
      echo -e "${YELLOW}  ⚠ Advertencia: ${#missing_scripts[@]} script(s) no se copiaron correctamente${NC}"
      for missing in "${missing_scripts[@]}"; do
        echo -e "${YELLOW}    - $missing${NC}"
      done
    fi
    
    return 0
  else
    echo -e "${RED}  ✗ Error al instalar $config_name${NC}"
    return 1
  fi
}

# Function to install all configurations
install_configurations() {
  local source_dir="$1"
  local make_backup="$2"
  local configs=("${@:3}")
  
  local installed=0
  local failed=0
  
  echo -e "${BLUE}Instalando configuraciones...${NC}"
  echo
  
  for config in "${configs[@]}"; do
    if install_single_config "$source_dir" "$config" "$make_backup"; then
      ((installed++))
    else
      ((failed++))
    fi
  done
  
  echo
  echo -e "${WHITE}Resumen de instalación:${NC}"
  echo -e "${GREEN}  ✓ Instaladas: $installed${NC}"
  if [[ $failed -gt 0 ]]; then
    echo -e "${RED}  ✗ Fallidas: $failed${NC}"
  fi
  
  return $failed
}

# Function to install individual config files (like dolphinrc, kdeglobals)
install_individual_config_files() {
  local source_dir="$1"
  local make_backup="$2"
  
  # List of individual config files to copy to ~/.config/
  local config_files=("dolphinrc" "kdeglobals")
  
  echo -e "${BLUE}Instalando archivos de configuración individuales...${NC}"
  echo
  
  for config_file in "${config_files[@]}"; do
    local source_file="$source_dir/$config_file"
    local target_file="$HOME/.config/$config_file"
    
    if [[ -f "$source_file" ]]; then
      echo -e "${BLUE}Instalando: $config_file${NC}"
      
      # Handle existing file
      if [[ -f "$target_file" ]]; then
        if [[ "$make_backup" == "true" ]]; then
          local backup_file="$target_file.backup.$(date +%Y%m%d_%H%M%S)"
          if mv "$target_file" "$backup_file"; then
            echo -e "${YELLOW}  • Backup creado: $(basename "$backup_file")${NC}"
          fi
        else
          echo -e "${YELLOW}  • Reemplazando archivo existente${NC}"
        fi
      fi
      
      # Copy file (force overwrite)
      if cp -f "$source_file" "$target_file"; then
        echo -e "${GREEN}  ✓ Instalado $config_file (sobrescrito)${NC}"
      else
        echo -e "${RED}  ✗ Error al instalar $config_file${NC}"
      fi
    else
      echo -e "${YELLOW}  ○ $config_file no encontrado, saltando...${NC}"
    fi
  done
  
  echo
}

# Function to create webapp-creator desktop file
create_webapp_creator_desktop() {
  local apps_dir="$HOME/.local/share/applications"
  local icons_dir="$HOME/.local/share/icons/webapp-icons"
  local desktop_file="$apps_dir/webapp-creator.desktop"
  local icon_path="$icons_dir/webapp-creator.png"
  local bin_path="$HOME/.local/bin/webapp-creator"

  echo -e "${BLUE}Creando/actualizando archivo .desktop de WebApp Creator...${NC}"

  # Create directories if they don't exist
  mkdir -p "$apps_dir" "$icons_dir"

  # Create icon for webapp-creator if it doesn't exist
  if [[ ! -f "$icon_path" ]]; then
    if command -v convert &>/dev/null; then
      convert -size 128x128 xc:transparent -fill "#4A90E2" -draw "circle 64,64 64,20" \
        -fill white -font DejaVu-Sans-Bold -pointsize 14 -gravity center \
        -annotate +0+0 "WEB\nAPP" "$icon_path" 2>/dev/null
      echo -e "${GREEN}  ✓ Icono creado${NC}"
    else
      # Try to copy a system icon as fallback
      for sys_icon in /usr/share/icons/hicolor/*/apps/preferences-system.png \
        /usr/share/pixmaps/preferences-system.png \
        /usr/share/icons/*/*/apps/application-default-icon.png; do
        if [[ -f "$sys_icon" ]]; then
          cp "$sys_icon" "$icon_path" 2>/dev/null && break
        fi
      done
    fi
  fi

  # Create or update the desktop file
  cat >"$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=WebApp Creator
Comment=Create and manage web applications
Exec=$bin_path
Icon=$icon_path
Categories=Development;System;Utility;
Keywords=webapp;browser;application;
NoDisplay=false
StartupNotify=true
Terminal=false
StartupWMClass=webapp-creator
EOF

  chmod +x "$desktop_file"
  
  # Update desktop database
  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$apps_dir" 2>/dev/null
  fi
  
  echo -e "${GREEN}  ✓ Archivo .desktop de WebApp Creator creado/actualizado${NC}"
  echo
}

# Function to install ORGMOS desktop files
install_orgmos_desktop_files() {
  local source_dir="$1"
  local apps_dir="$HOME/.local/share/applications"
  local desktop_files=(
    "orgmos-webapp-creator.desktop"
    "orgmos-display-manager.desktop"
    "orgmos-wallpaper-selector.desktop"
    "orgmos-game-mode.desktop"
    "orgmos-desktop-apps.desktop"
    "Video-Downloader.desktop"
  )
  
  echo -e "${BLUE}Instalando archivos .desktop de aplicaciones ORGMOS...${NC}"
  
  # Create applications directory if it doesn't exist
  mkdir -p "$apps_dir"
  
  local installed=0
  # Obtener el directorio del repositorio desde el directorio padre de Apps
  local repo_dir="$(dirname "$source_dir")"
  
  for desktop_file in "${desktop_files[@]}"; do
    local source_file="$source_dir/$desktop_file"
    local target_file="$apps_dir/$desktop_file"
    
    if [[ -f "$source_file" ]]; then
      # Replace %h with $HOME in Exec and Icon paths
      # Also replace Myconfig with actual repo directory name if needed
      sed -e "s|%h|$HOME|g" -e "s|Myconfig|$(basename "$repo_dir")|g" "$source_file" > "$target_file"
      chmod +x "$target_file"
      echo -e "${GREEN}  ✓ Instalado $desktop_file${NC}"
      ((installed++))
    else
      echo -e "${YELLOW}  ○ $desktop_file no encontrado, saltando...${NC}"
    fi
  done
  
  # Update desktop database
  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$apps_dir" 2>/dev/null
    echo -e "${GREEN}  ✓ Base de datos de aplicaciones actualizada${NC}"
  fi
  
  if [[ $installed -gt 0 ]]; then
    echo -e "${GREEN}✓ $installed archivo(s) .desktop de ORGMOS instalado(s)${NC}"
  fi
  echo
}

# Function to refresh system components
refresh_system_components() {
  echo -e "${BLUE}Refrescando componentes del sistema...${NC}"
  
  # Refresh i3 (Win+Shift+R equivalent)
  if command -v i3-msg &>/dev/null; then
    echo -e "${CYAN}  • Reiniciando i3...${NC}"
    i3-msg restart 2>/dev/null || true
  fi
  
  # Reload i3 config (Win+Alt+R equivalent)
  if command -v i3-msg &>/dev/null; then
    echo -e "${CYAN}  • Recargando configuración de i3...${NC}"
    i3-msg reload 2>/dev/null || true
  fi
  
  # Restart polybar if running
  if pgrep polybar &>/dev/null; then
    echo -e "${CYAN}  • Reiniciando polybar...${NC}"
    polybar-msg cmd restart 2>/dev/null || true
  fi
  
  # Restart picom if running
  if pgrep picom &>/dev/null; then
    echo -e "${CYAN}  • Reiniciando picom...${NC}"
    pkill -USR1 picom 2>/dev/null || true
  fi
  
  echo -e "${GREEN}✓ Componentes refrescados${NC}"
}

# Function to show completion message
show_completion() {
  local installed_count="$1"
  
  echo
  echo -e "${GREEN}✓ ¡Configuraciones instaladas exitosamente!${NC}"
  echo
  echo -e "${WHITE}Resultado:${NC}"
  echo -e "${BLUE}  • Configuraciones instaladas: $installed_count${NC}"
  echo -e "${BLUE}  • Ubicación: ~/.config/${NC}"
  echo
  
  # Refresh system components
  refresh_system_components
  
  echo
  echo -e "${YELLOW}Nota importante:${NC}"
  echo -e "${BLUE}  • Los componentes del sistema han sido refrescados automáticamente${NC}"
  echo -e "${BLUE}  • Para fish: Ejecuta 'source ~/.config/fish/config.fish'${NC}"
  echo
}

# Main execution
main() {
  # Validate source directory
  if ! validate_source_directory "$REPO_DIR"; then
    exit 1
  fi
  
  # List available configurations
  local configs_array=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && configs_array+=("$line")
  done < <(list_configurations "$REPO_DIR")
  
  if [[ ${#configs_array[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No se encontraron configuraciones para instalar${NC}"
    exit 0
  fi
  
  # Show configuration details
  show_config_details "$REPO_DIR" "${configs_array[@]}"
  
  # Install configurations without backup (always overwrite)
  local backup_mode="false"
  echo -e "${BLUE}Iniciando instalación automática...${NC}"
  echo
  
  # Install configurations
  if install_configurations "$REPO_DIR" "false" "${configs_array[@]}"; then
    # Install individual config files (dolphinrc, kdeglobals, etc.)
    install_individual_config_files "$REPO_DIR" "false"
    
    # Create/update webapp-creator desktop file
    create_webapp_creator_desktop
    
    # Install ORGMOS desktop files
    install_orgmos_desktop_files "$REPO_DIR/Apps"
    
    # Show completion message and refresh system
    show_completion "${#configs_array[@]}"
  else
    exit 1
  fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
