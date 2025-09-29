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
      
      # Skip Apps and Launcher directories
      if [[ "$dir_name" != "Apps" && "$dir_name" != "Launcher" ]]; then
        configs+=("$dir_name")
      fi
    fi
  done
  
  printf '%s\n' "${configs[@]}"
}

# Function to show configuration details
show_config_details() {
  local source_dir="$1"
  local configs=("$@")
  
  echo -e "${WHITE}Configuraciones encontradas:${NC}"
  echo
  
  for config in "${configs[@]:1}"; do
    local config_path="$source_dir/$config"
    local file_count=$(find "$config_path" -type f 2>/dev/null | wc -l)
    local target_path="$HOME/.config/$config"
    local status=""
    
    if [[ -d "$target_path" ]]; then
      status="${YELLOW}(existente)${NC}"
    else
      status="${GREEN}(nuevo)${NC}"
    fi
    
    echo -e "${CYAN}  • $config${NC} $status - $file_count archivos"
  done
  
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
    echo -e "${GREEN}  ✓ Instalado $config_name ($file_count archivos)${NC}"
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
  echo -e "${YELLOW}Nota importante:${NC}"
  echo -e "${BLUE}  • Algunas aplicaciones requieren reinicio para aplicar cambios${NC}"
  echo -e "${BLUE}  • Para i3/polybar: Reinicia tu sesión o recarga la configuración${NC}"
  echo -e "${BLUE}  • Para fish: Ejecuta 'source ~/.config/fish/config.fish'${NC}"
  echo
}

# Main execution
main() {
  show_header
  
  echo -e "${BLUE}Directorio fuente: $REPO_DIR${NC}"
  echo
  
  # Validate source directory
  if ! validate_source_directory "$REPO_DIR"; then
    echo -e "${RED}✗ No se puede continuar sin un directorio fuente válido${NC}"
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
  
  # Ask for backup preference
  echo -e "${YELLOW}¿Crear backups de las configuraciones existentes? (y/N):${NC} "
  read -r make_backups </dev/tty
  
  local backup_mode="false"
  if [[ "$make_backups" =~ ^[Yy]$ ]]; then
    backup_mode="true"
    echo -e "${GREEN}Se crearán backups de configuraciones existentes${NC}"
  else
    echo -e "${BLUE}Las configuraciones existentes serán reemplazadas${NC}"
  fi
  
  echo
  echo -e "${YELLOW}¿Continuar con la instalación? (y/N):${NC} "
  read -r confirm </dev/tty
  
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Instalación cancelada${NC}"
    exit 0
  fi
  
  echo
  
  # Install configurations
  if install_configurations "$REPO_DIR" "$backup_mode" "${configs_array[@]}"; then
    show_completion "${#configs_array[@]}"
  else
    echo -e "${RED}✗ Algunas configuraciones fallaron. Revisa los mensajes anteriores.${NC}"
    exit 1
  fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
