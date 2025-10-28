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
      
      # Skip Apps, Launcher, sddm, and Wallpapers directories
      if [[ "$dir_name" == "Apps" || "$dir_name" == "Launcher" || "$dir_name" == "sddm" || "$dir_name" == "Wallpapers" ]]; then
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
  
  # Copy new configuration
  if cp -r "$source_path" "$target_path"; then
    local file_count=$(find "$target_path" -type f | wc -l)
    
    # Give execute permissions to scripts
    find "$target_path" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null
    
    echo -e "${GREEN}  ✓ Instalado $config_name ($file_count archivos)${NC}"
    echo -e "${BLUE}  ✓ Permisos de ejecución otorgados a scripts .sh${NC}"
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

# Function to create Desktop Apps application
create_desktop_apps() {
  local apps_dir="$HOME/.local/share/applications"
  local desktop_file="$apps_dir/desktop-apps.desktop"
  
  echo -e "${BLUE}Creando aplicación Desktop Apps...${NC}"
  
  mkdir -p "$apps_dir"
  
  cat >"$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Desktop Apps
Comment=Open local applications directory
Exec=xdg-open $HOME/.local/share/applications
Icon=folder-applications
Categories=System;Utility;
Terminal=false
NoDisplay=false
StartupNotify=true
EOF

  chmod +x "$desktop_file"
  echo -e "${GREEN}✓ Aplicación Desktop Apps creada${NC}"
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
    # Create Desktop Apps application
    create_desktop_apps
    
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
