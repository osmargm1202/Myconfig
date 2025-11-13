#!/usr/bin/env bash

# Google Cloud CLI Installer
# Installs Google Cloud CLI following official documentation

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
  echo -e "${CYAN}║     Google Cloud CLI Installer        ║${NC}"
  echo -e "${CYAN}║      Install and Configure gcloud     ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
  echo
}

# Function to detect platform
detect_platform() {
  local arch=$(uname -m)
  local platform=""
  
  if [[ "$arch" == "x86_64" ]]; then
    platform="linux-x86_64"
  elif [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    platform="linux-arm"
  elif [[ "$arch" == "i386" || "$arch" == "i686" ]]; then
    platform="linux-x86"
  else
    echo -e "${RED}✗ Arquitectura no soportada: $arch${NC}"
    return 1
  fi
  
  echo "$platform"
  return 0
}

# Function to check if gcloud is already installed
check_gcloud_installed() {
  if command -v gcloud &>/dev/null; then
    echo -e "${YELLOW}⚠ Google Cloud CLI ya está instalado${NC}"
    gcloud --version | head -n 1
    echo
    echo -ne "${YELLOW}¿Deseas reinstalarlo? (y/N): ${NC}"
    read -r reinstall </dev/tty
    if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
      return 1
    fi
  fi
  return 0
}

# Function to check Python version
check_python() {
  if command -v python3 &>/dev/null; then
    local python_version=$(python3 --version 2>&1 | awk '{print $2}')
    echo -e "${GREEN}✓ Python encontrado: $python_version${NC}"
    return 0
  else
    echo -e "${YELLOW}⚠ Python 3 no encontrado${NC}"
    echo -e "${BLUE}El instalador de gcloud incluye Python, pero es recomendable tener Python 3.9-3.14 instalado${NC}"
    return 0
  fi
}

# Function to download and install gcloud CLI
install_gcloud() {
  local platform=$(detect_platform)
  if [[ -z "$platform" ]]; then
    return 1
  fi
  
  local download_url="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${platform}.tar.gz"
  local temp_dir=$(mktemp -d)
  local archive_file="$temp_dir/google-cloud-cli-${platform}.tar.gz"
  local install_dir="$HOME/google-cloud-sdk"
  
  echo -e "${BLUE}Descargando Google Cloud CLI para $platform...${NC}"
  echo -e "${CYAN}URL: $download_url${NC}"
  echo
  
  # Download the archive
  if command -v curl &>/dev/null; then
    if ! curl -L -o "$archive_file" "$download_url"; then
      echo -e "${RED}✗ Error al descargar el archivo${NC}"
      rm -rf "$temp_dir"
      return 1
    fi
  elif command -v wget &>/dev/null; then
    if ! wget -O "$archive_file" "$download_url"; then
      echo -e "${RED}✗ Error al descargar el archivo${NC}"
      rm -rf "$temp_dir"
      return 1
    fi
  else
    echo -e "${RED}✗ curl o wget no están instalados${NC}"
    rm -rf "$temp_dir"
    return 1
  fi
  
  echo -e "${GREEN}✓ Descarga completada${NC}"
  echo
  
  # Extract the archive
  echo -e "${BLUE}Extrayendo archivo...${NC}"
  if [[ -d "$install_dir" ]]; then
    echo -e "${YELLOW}  • Removiendo instalación existente${NC}"
    rm -rf "$install_dir"
  fi
  
  if ! tar -xzf "$archive_file" -C "$HOME"; then
    echo -e "${RED}✗ Error al extraer el archivo${NC}"
    rm -rf "$temp_dir"
    return 1
  fi
  
  echo -e "${GREEN}✓ Extracción completada${NC}"
  echo
  
  # Run installation script
  echo -e "${BLUE}Ejecutando script de instalación...${NC}"
  echo -e "${YELLOW}Nota: El script te preguntará si deseas agregar gcloud a tu PATH${NC}"
  echo
  
  # Run install.sh non-interactively with recommended options
  if "$install_dir/install.sh" --quiet --path-update=true --bash-completion=true --usage-reporting=false; then
    echo -e "${GREEN}✓ Instalación completada${NC}"
  else
    echo -e "${YELLOW}⚠ La instalación automática falló, intentando modo interactivo...${NC}"
    "$install_dir/install.sh"
  fi
  
  # Clean up
  rm -rf "$temp_dir"
  
  # Check if gcloud is now in PATH
  if command -v gcloud &>/dev/null; then
    echo -e "${GREEN}✓ gcloud está disponible en PATH${NC}"
    return 0
  else
    echo -e "${YELLOW}⚠ gcloud no está en PATH${NC}"
    echo -e "${BLUE}Agrega esta línea a tu ~/.bashrc, ~/.zshrc o ~/.config/fish/config.fish:${NC}"
    echo -e "${WHITE}export PATH=\"\$HOME/google-cloud-sdk/bin:\$PATH\"${NC}"
    echo
    echo -e "${BLUE}O ejecuta:${NC}"
    echo -e "${WHITE}source \$HOME/google-cloud-sdk/path.bash.inc${NC}"
    return 0
  fi
}

# Function to show post-installation instructions
show_post_install_instructions() {
  echo
  echo -e "${GREEN}✓ ¡Google Cloud CLI instalado exitosamente!${NC}"
  echo
  echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}Próximos pasos para configurar tu entorno:${NC}"
  echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
  echo
  echo -e "${YELLOW}1. Inicializar gcloud CLI:${NC}"
  echo -e "${WHITE}   gcloud init${NC}"
  echo
  echo -e "${YELLOW}2. Autenticarse con tu cuenta de Google:${NC}"
  echo -e "${WHITE}   gcloud auth login${NC}"
  echo -e "${BLUE}   Esto abrirá tu navegador para autenticarte${NC}"
  echo
  echo -e "${YELLOW}3. Configurar Docker para usar gcloud como helper:${NC}"
  echo -e "${WHITE}   gcloud auth configure-docker${NC}"
  echo -e "${BLUE}   Esto configurará Docker para autenticarse con Google Container Registry${NC}"
  echo
  echo -e "${YELLOW}4. (Opcional) Configurar Application Default Credentials:${NC}"
  echo -e "${WHITE}   gcloud auth application-default login${NC}"
  echo -e "${BLUE}   Útil para desarrollo local y aplicaciones${NC}"
  echo
  echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
  echo
  echo -e "${BLUE}Documentación completa:${NC}"
  echo -e "${WHITE}https://cloud.google.com/sdk/docs${NC}"
  echo
}

# Main execution
main() {
  show_header
  
  # Check if already installed
  if ! check_gcloud_installed; then
    echo -e "${BLUE}Instalación cancelada${NC}"
    exit 0
  fi
  
  echo
  
  # Check Python
  check_python
  echo
  
  # Install gcloud
  if install_gcloud; then
    show_post_install_instructions
  else
    echo -e "${RED}✗ Error en la instalación de Google Cloud CLI${NC}"
    exit 1
  fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

