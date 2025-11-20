#!/usr/bin/env bash

# ORGMOS Server Installer
# Instalación automática de herramientas de servidor, shell, docker, fish, starship y gcloud

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to display header
show_header() {
  clear
  echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║      ORGMOS Server Installer          ║${NC}"
  echo -e "${CYAN}║   Server Tools & Configuration        ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
  echo
}

# Function to check if running as root
check_root() {
  if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}✗ Este script no debe ejecutarse como root${NC}"
    echo -e "${BLUE}Ejecuta como usuario normal, se pedirán permisos sudo cuando sea necesario${NC}"
    exit 1
  fi
}

# Function to debug log
debug_log() {
  echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Function to install packages from pkg_server.lst
install_server_packages() {
  local script_dir="$(dirname "$(realpath "$0")")"
  local pkg_list="${script_dir}/pkg_server.lst"
  
  debug_log "Iniciando instalación de paquetes desde pkg_server.lst"
  
  if [[ ! -f "$pkg_list" ]]; then
    echo -e "${RED}✗ Archivo pkg_server.lst no encontrado: $pkg_list${NC}"
    return 1
  fi
  
  echo -e "${BLUE}Instalando paquetes de servidor...${NC}"
  echo
  
  # Use install_pkg.sh with pkg_server.lst
  if [[ -f "${script_dir}/install_pkg.sh" ]]; then
    debug_log "Ejecutando install_pkg.sh con pkg_server.lst"
    "${script_dir}/install_pkg.sh" "$pkg_list"
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✓ Paquetes instalados exitosamente${NC}"
      return 0
    else
      echo -e "${RED}✗ Error al instalar paquetes${NC}"
      return 1
    fi
  else
    echo -e "${RED}✗ Script install_pkg.sh no encontrado${NC}"
    return 1
  fi
}

# Function to configure fish as login shell
configure_fish_shell() {
  debug_log "Configurando fish como shell de login"
  
  # Check if fish is installed
  if ! command -v fish &>/dev/null; then
    echo -e "${YELLOW}⚠ Fish no está instalado, se instalará con los paquetes${NC}"
    return 1
  fi
  
  local fish_path=$(command -v fish)
  debug_log "Ruta de fish: $fish_path"
  
  # Add fish to /etc/shells if not already present
  if ! grep -q "$fish_path" /etc/shells 2>/dev/null; then
    echo -e "${BLUE}Agregando fish a /etc/shells...${NC}"
    echo "$fish_path" | sudo tee -a /etc/shells > /dev/null
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✓ Fish agregado a /etc/shells${NC}"
      debug_log "Fish agregado exitosamente a /etc/shells"
    else
      echo -e "${RED}✗ Error al agregar fish a /etc/shells${NC}"
      return 1
    fi
  else
    echo -e "${GREEN}✓ Fish ya está en /etc/shells${NC}"
    debug_log "Fish ya existe en /etc/shells"
  fi
  
  # Change default shell to fish
  local current_shell=$(getent passwd "$USER" | cut -d: -f7)
  debug_log "Shell actual: $current_shell"
  
  if [[ "$current_shell" != "$fish_path" ]]; then
    echo -e "${BLUE}Cambiando shell predeterminado a fish...${NC}"
    if chsh -s "$fish_path"; then
      echo -e "${GREEN}✓ Shell predeterminado cambiado a fish${NC}"
      debug_log "Shell cambiado exitosamente a: $fish_path"
      echo -e "${YELLOW}⚠ Nota: El cambio de shell se aplicará en el próximo inicio de sesión${NC}"
    else
      echo -e "${RED}✗ Error al cambiar el shell predeterminado${NC}"
      return 1
    fi
  else
    echo -e "${GREEN}✓ Fish ya es el shell predeterminado${NC}"
    debug_log "Fish ya es el shell predeterminado"
  fi
  
  return 0
}

# Function to copy configuration directory
copy_config_directory() {
  local config_name="$1"
  local source_dir="$2"
  local target_dir="$3"
  
  debug_log "Copiando configuración de $config_name"
  
  if [[ ! -d "$source_dir" ]]; then
    echo -e "${YELLOW}⚠ Directorio $config_name no encontrado en repositorio: $source_dir${NC}"
    debug_log "Directorio $config_name no encontrado: $source_dir"
    return 1
  fi
  
  echo -e "${BLUE}Copiando configuración de $config_name...${NC}"
  debug_log "Origen: $source_dir"
  debug_log "Destino: $target_dir"
  
  # Create target directory if it doesn't exist
  mkdir -p "$target_dir"
  
  # Backup existing config if it exists
  if [[ -d "$target_dir" && -n "$(ls -A "$target_dir" 2>/dev/null)" ]]; then
    local backup_dir="$target_dir.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}  • Creando backup de configuración existente...${NC}"
    if cp -r "$target_dir" "$backup_dir" 2>/dev/null; then
      echo -e "${GREEN}  ✓ Backup creado: $(basename "$backup_dir")${NC}"
      debug_log "Backup creado: $backup_dir"
    fi
  fi
  
  # Copy configuration
  if cp -rf "$source_dir"/* "$target_dir"/ 2>/dev/null; then
    echo -e "${GREEN}✓ Configuración de $config_name copiada exitosamente${NC}"
    debug_log "Configuración de $config_name copiada exitosamente"
    
    # Count files copied
    local file_count=$(find "$target_dir" -type f 2>/dev/null | wc -l)
    echo -e "${BLUE}  • Archivos copiados: $file_count${NC}"
    
    return 0
  else
    echo -e "${RED}✗ Error al copiar configuración de $config_name${NC}"
    debug_log "Error al copiar configuración de $config_name"
    return 1
  fi
}

# Function to copy fish configuration
copy_fish_config() {
  local script_dir="$(dirname "$(realpath "$0")")"
  local repo_dir="$(dirname "$script_dir")"
  local fish_source="$repo_dir/fish"
  local fish_target="$HOME/.config/fish"
  
  copy_config_directory "Fish" "$fish_source" "$fish_target"
}

# Function to copy fastfetch configuration
copy_fastfetch_config() {
  local script_dir="$(dirname "$(realpath "$0")")"
  local repo_dir="$(dirname "$script_dir")"
  local fastfetch_source="$repo_dir/fastfetch"
  local fastfetch_target="$HOME/.config/fastfetch"
  
  copy_config_directory "Fastfetch" "$fastfetch_source" "$fastfetch_target"
}

# Function to copy starship configuration
copy_starship_config() {
  local script_dir="$(dirname "$(realpath "$0")")"
  local repo_dir="$(dirname "$script_dir")"
  local starship_source="$repo_dir/starship"
  local starship_toml_source="$starship_source/starship.toml"
  local starship_toml_target="$HOME/.config/starship.toml"
  
  debug_log "Copiando configuración de Starship"
  
  if [[ ! -d "$starship_source" ]]; then
    echo -e "${YELLOW}⚠ Directorio starship no encontrado en repositorio: $starship_source${NC}"
    debug_log "Directorio starship no encontrado: $starship_source"
    return 1
  fi
  
  if [[ ! -f "$starship_toml_source" ]]; then
    echo -e "${YELLOW}⚠ Archivo starship.toml no encontrado: $starship_toml_source${NC}"
    debug_log "Archivo starship.toml no encontrado: $starship_toml_source"
    return 1
  fi
  
  echo -e "${BLUE}Copiando configuración de Starship...${NC}"
  debug_log "Origen: $starship_toml_source"
  debug_log "Destino: $starship_toml_target"
  
  # Backup existing config if it exists
  if [[ -f "$starship_toml_target" ]]; then
    local backup_file="$starship_toml_target.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}  • Creando backup de configuración existente...${NC}"
    if cp "$starship_toml_target" "$backup_file" 2>/dev/null; then
      echo -e "${GREEN}  ✓ Backup creado: $(basename "$backup_file")${NC}"
      debug_log "Backup creado: $backup_file"
    fi
  fi
  
  # Copy starship.toml
  if cp -f "$starship_toml_source" "$starship_toml_target" 2>/dev/null; then
    echo -e "${GREEN}✓ Configuración de Starship copiada exitosamente${NC}"
    debug_log "Configuración de Starship copiada exitosamente"
    echo -e "${BLUE}  • Archivo: $starship_toml_target${NC}"
    return 0
  else
    echo -e "${RED}✗ Error al copiar configuración de Starship${NC}"
    debug_log "Error al copiar configuración de Starship"
    return 1
  fi
}

# Function to verify starship is installed
verify_starship_installed() {
  debug_log "Verificando que Starship esté instalado"
  
  if ! command -v starship &>/dev/null; then
    echo -e "${YELLOW}⚠ Starship no está instalado${NC}"
    echo -e "${BLUE}Starship debería haberse instalado con los paquetes${NC}"
    debug_log "Starship no encontrado en PATH"
    return 1
  fi
  
  local starship_version=$(starship --version 2>/dev/null | head -n 1)
  echo -e "${GREEN}✓ Starship está instalado${NC}"
  echo -e "${BLUE}  • Versión: $starship_version${NC}"
  debug_log "Starship verificado: $starship_version"
  return 0
}

# Function to install and configure gcloud
install_gcloud() {
  debug_log "Instalando y configurando Google Cloud CLI"
  
  local script_dir="$(dirname "$(realpath "$0")")"
  
  if [[ -f "${script_dir}/install_gcloud.sh" ]]; then
    echo -e "${BLUE}Instalando Google Cloud CLI...${NC}"
    debug_log "Ejecutando install_gcloud.sh"
    "${script_dir}/install_gcloud.sh"
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✓ Google Cloud CLI instalado exitosamente${NC}"
      debug_log "Google Cloud CLI instalado"
      return 0
    else
      echo -e "${YELLOW}⚠ Advertencia: Error al instalar Google Cloud CLI${NC}"
      return 1
    fi
  else
    echo -e "${YELLOW}⚠ Script install_gcloud.sh no encontrado${NC}"
    return 1
  fi
}

# Function to configure docker
configure_docker() {
  debug_log "Configurando Docker"
  
  # Check if docker is installed
  if ! command -v docker &>/dev/null; then
    echo -e "${YELLOW}⚠ Docker no está instalado, se instalará con los paquetes${NC}"
    return 1
  fi
  
  echo -e "${BLUE}Configurando Docker...${NC}"
  
  # Enable docker service
  if systemctl is-enabled docker &>/dev/null; then
    echo -e "${GREEN}✓ Servicio Docker ya está habilitado${NC}"
    debug_log "Servicio Docker ya habilitado"
  else
    echo -e "${BLUE}Habilitando servicio Docker...${NC}"
    if sudo systemctl enable docker; then
      echo -e "${GREEN}✓ Servicio Docker habilitado${NC}"
      debug_log "Servicio Docker habilitado exitosamente"
    else
      echo -e "${RED}✗ Error al habilitar servicio Docker${NC}"
      return 1
    fi
  fi
  
  # Start docker service
  if systemctl is-active docker &>/dev/null; then
    echo -e "${GREEN}✓ Servicio Docker ya está en ejecución${NC}"
    debug_log "Servicio Docker ya en ejecución"
  else
    echo -e "${BLUE}Iniciando servicio Docker...${NC}"
    if sudo systemctl start docker; then
      echo -e "${GREEN}✓ Servicio Docker iniciado${NC}"
      debug_log "Servicio Docker iniciado exitosamente"
    else
      echo -e "${RED}✗ Error al iniciar servicio Docker${NC}"
      return 1
    fi
  fi
  
  # Add user to docker group
  if groups "$USER" | grep -q docker; then
    echo -e "${GREEN}✓ Usuario ya está en el grupo docker${NC}"
    debug_log "Usuario ya en grupo docker"
  else
    echo -e "${BLUE}Agregando usuario al grupo docker...${NC}"
    if sudo usermod -aG docker "$USER"; then
      echo -e "${GREEN}✓ Usuario agregado al grupo docker${NC}"
      debug_log "Usuario agregado al grupo docker"
      echo -e "${YELLOW}⚠ Nota: Debes cerrar sesión y volver a iniciar para que los cambios del grupo tengan efecto${NC}"
    else
      echo -e "${RED}✗ Error al agregar usuario al grupo docker${NC}"
      return 1
    fi
  fi
  
  return 0
}

# Function to install ORGMOS terminal commands
install_orgmos_commands() {
  debug_log "Instalando comandos de terminal ORGMOS"
  
  local script_dir="$(dirname "$(realpath "$0")")"
  local repo_dir="$(dirname "$script_dir")"
  local bin_dir="$HOME/.local/bin"
  
  echo -e "${BLUE}Instalando comandos de terminal ORGMOS...${NC}"
  
  # Create bin directory if it doesn't exist
  mkdir -p "$bin_dir"
  
  local installed=0
  local commands=("orgmos" "orgmos-server")
  
  for cmd in "${commands[@]}"; do
    local source_file="$script_dir/$cmd"
    local target_file="$bin_dir/$cmd"
    
    if [[ -f "$source_file" ]]; then
      if cp -f "$source_file" "$target_file"; then
        chmod +x "$target_file"
        echo -e "${GREEN}  ✓ Instalado comando: $cmd${NC}"
        debug_log "Comando instalado: $cmd"
        ((installed++))
      else
        echo -e "${RED}  ✗ Error al instalar $cmd${NC}"
        debug_log "Error al instalar: $cmd"
      fi
    else
      echo -e "${YELLOW}  ○ $cmd no encontrado, saltando...${NC}"
      debug_log "Comando no encontrado: $cmd"
    fi
  done
  
  # Check if bin_dir is in PATH
  if ! echo "$PATH" | grep -q "$bin_dir"; then
    echo -e "${YELLOW}  ⚠ Advertencia: $bin_dir no está en tu PATH${NC}"
    echo -e "${BLUE}  Agrega esta línea a tu ~/.bashrc, ~/.zshrc o ~/.config/fish/config.fish:${NC}"
    echo -e "${GREEN}  export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo -e "${GREEN}  # Para fish: fish_add_path ~/.local/bin${NC}"
    debug_log "Advertencia: $bin_dir no está en PATH"
  else
    debug_log "$bin_dir está en PATH"
  fi
  
  if [[ $installed -gt 0 ]]; then
    echo -e "${GREEN}✓ $installed comando(s) de terminal instalado(s)${NC}"
    echo -e "${BLUE}  • Usa 'orgmos' para ejecutar el menú principal${NC}"
    echo -e "${BLUE}  • Usa 'orgmos-server' para instalar el servidor${NC}"
  fi
  echo
  
  return 0
}

# Main execution
main() {
  check_root
  show_header
  
  echo -e "${WHITE}Este instalador configurará:${NC}"
  echo -e "${BLUE}  • Herramientas de shell y terminal${NC}"
  echo -e "${BLUE}  • Docker y configuración${NC}"
  echo -e "${BLUE}  • Fish shell como shell predeterminado${NC}"
  echo -e "${BLUE}  • Configuraciones: Fish, Fastfetch, Starship${NC}"
  echo -e "${BLUE}  • Google Cloud CLI${NC}"
  echo -e "${BLUE}  • Comandos de terminal: orgmos, orgmos-server${NC}"
  echo
  echo -e "${YELLOW}Instalación automática iniciando...${NC}"
  echo
  
  local errors=0
  
  # Step 1: Install packages
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Paso 1/9: Instalando paquetes${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  if ! install_server_packages; then
    ((errors++))
    echo -e "${RED}✗ Error en la instalación de paquetes${NC}"
  fi
  echo
  
  # Step 2: Configure fish shell
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Paso 2/9: Configurando Fish Shell${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  if ! configure_fish_shell; then
    ((errors++))
    echo -e "${YELLOW}⚠ Advertencia: No se pudo configurar Fish Shell${NC}"
  fi
  echo
  
  # Step 3: Copy fish configuration
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Paso 3/9: Copiando configuración de Fish${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  if ! copy_fish_config; then
    ((errors++))
    echo -e "${YELLOW}⚠ Advertencia: No se pudo copiar configuración de Fish${NC}"
  fi
  echo
  
  # Step 4: Copy fastfetch configuration
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Paso 4/9: Copiando configuración de Fastfetch${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  if ! copy_fastfetch_config; then
    ((errors++))
    echo -e "${YELLOW}⚠ Advertencia: No se pudo copiar configuración de Fastfetch${NC}"
  fi
  echo
  
  # Step 5: Verify starship is installed
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Paso 5/9: Verificando Starship${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  if ! verify_starship_installed; then
    ((errors++))
    echo -e "${YELLOW}⚠ Advertencia: Starship no está instalado${NC}"
  fi
  echo
  
  # Step 6: Copy starship configuration
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Paso 6/9: Copiando configuración de Starship${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  if ! copy_starship_config; then
    ((errors++))
    echo -e "${YELLOW}⚠ Advertencia: No se pudo copiar configuración de Starship${NC}"
  fi
  echo
  
  # Step 7: Install gcloud
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Paso 7/9: Instalando Google Cloud CLI${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  if ! install_gcloud; then
    ((errors++))
    echo -e "${YELLOW}⚠ Advertencia: No se pudo instalar Google Cloud CLI${NC}"
  fi
  echo
  
  # Step 8: Configure docker
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Paso 8/9: Configurando Docker${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  if ! configure_docker; then
    ((errors++))
    echo -e "${YELLOW}⚠ Advertencia: No se pudo configurar Docker${NC}"
  fi
  echo
  
  # Step 9: Install ORGMOS terminal commands
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Paso 9/9: Instalando comandos de terminal${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  if ! install_orgmos_commands; then
    ((errors++))
    echo -e "${YELLOW}⚠ Advertencia: No se pudieron instalar los comandos${NC}"
  fi
  echo
  
  # Summary
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Resumen de Instalación${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  
  if [[ $errors -eq 0 ]]; then
    echo -e "${GREEN}✓ ¡Instalación completada exitosamente!${NC}"
    echo
    echo -e "${WHITE}Próximos pasos:${NC}"
    echo -e "${BLUE}  • Cierra sesión y vuelve a iniciar para aplicar el cambio de shell a Fish${NC}"
    echo -e "${BLUE}  • Si agregaste tu usuario al grupo docker, también necesitas cerrar sesión${NC}"
    echo -e "${BLUE}  • Configura gcloud con: gcloud init${NC}"
    echo -e "${BLUE}  • Autentica gcloud con: gcloud auth login${NC}"
    echo
    echo -e "${WHITE}Comandos disponibles:${NC}"
    echo -e "${GREEN}  • orgmos${NC} - Ejecuta el menú principal de ORGMOS"
    echo -e "${GREEN}  • orgmos-server${NC} - Ejecuta la instalación del servidor"
  else
    echo -e "${YELLOW}⚠ Instalación completada con $errors advertencia(s)${NC}"
    echo -e "${BLUE}Revisa los mensajes anteriores para más detalles${NC}"
  fi
  echo
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

