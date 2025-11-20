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

# Function to install and configure starship
install_starship() {
  debug_log "Instalando y configurando Starship"
  
  local script_dir="$(dirname "$(realpath "$0")")"
  local repo_dir="$(dirname "$script_dir")"
  
  if [[ -f "${script_dir}/install_starship.sh" ]]; then
    echo -e "${BLUE}Instalando configuración de Starship...${NC}"
    debug_log "Ejecutando install_starship.sh con flag -y"
    "${script_dir}/install_starship.sh" -y
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✓ Starship configurado exitosamente${NC}"
      debug_log "Starship instalado y configurado"
      return 0
    else
      echo -e "${YELLOW}⚠ Advertencia: Error al configurar Starship${NC}"
      return 1
    fi
  else
    echo -e "${YELLOW}⚠ Script install_starship.sh no encontrado${NC}"
    return 1
  fi
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

# Main execution
main() {
  check_root
  show_header
  
  echo -e "${WHITE}Este instalador configurará:${NC}"
  echo -e "${BLUE}  • Herramientas de shell y terminal${NC}"
  echo -e "${BLUE}  • Docker y configuración${NC}"
  echo -e "${BLUE}  • Fish shell como shell predeterminado${NC}"
  echo -e "${BLUE}  • Starship prompt${NC}"
  echo -e "${BLUE}  • Google Cloud CLI${NC}"
  echo
  echo -e "${YELLOW}Instalación automática iniciando...${NC}"
  echo
  
  local errors=0
  
  # Step 1: Install packages
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Paso 1/5: Instalando paquetes${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  if ! install_server_packages; then
    ((errors++))
    echo -e "${RED}✗ Error en la instalación de paquetes${NC}"
  fi
  echo
  
  # Step 2: Configure fish shell
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Paso 2/5: Configurando Fish Shell${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  if ! configure_fish_shell; then
    ((errors++))
    echo -e "${YELLOW}⚠ Advertencia: No se pudo configurar Fish Shell${NC}"
  fi
  echo
  
  # Step 3: Install starship
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Paso 3/5: Instalando Starship${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  if ! install_starship; then
    ((errors++))
    echo -e "${YELLOW}⚠ Advertencia: No se pudo instalar Starship${NC}"
  fi
  echo
  
  # Step 4: Install gcloud
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Paso 4/5: Instalando Google Cloud CLI${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  if ! install_gcloud; then
    ((errors++))
    echo -e "${YELLOW}⚠ Advertencia: No se pudo instalar Google Cloud CLI${NC}"
  fi
  echo
  
  # Step 5: Configure docker
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}Paso 5/5: Configurando Docker${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo
  if ! configure_docker; then
    ((errors++))
    echo -e "${YELLOW}⚠ Advertencia: No se pudo configurar Docker${NC}"
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

