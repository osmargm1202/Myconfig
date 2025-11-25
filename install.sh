#!/usr/bin/env bash

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_URL="https://github.com/osmargm1202/Myconfig.git"
REPO_DIR="$HOME/Myconfig"

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      ORGMOS Installation Script       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo

# Verificar/instalar Go
if ! command -v go &> /dev/null; then
    echo -e "${YELLOW}Go no está instalado. Instalando...${NC}"
    if command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm go
    elif command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y golang-go
    else
        echo -e "${RED}No se pudo instalar Go automáticamente. Instálalo manualmente.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Go instalado: $(go version)${NC}"

# Clonar o actualizar repositorio
if [ -d "$REPO_DIR" ]; then
    echo -e "${BLUE}Actualizando repositorio existente...${NC}"
    cd "$REPO_DIR"
    git pull origin master || git pull origin main || true
else
    echo -e "${BLUE}Clonando repositorio...${NC}"
    git clone "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
fi

# Compilar binario
echo -e "${BLUE}Compilando binario...${NC}"
if command -v make &> /dev/null; then
    make install
else
    # Fallback sin make
    go build -o "$REPO_DIR/orgmos" ./cmd/orgmos
    REPO_DIR_ABS="$(cd "$REPO_DIR" && pwd)"
    if [ -L /usr/local/bin/orgmos ] || [ -f /usr/local/bin/orgmos ]; then
        sudo rm /usr/local/bin/orgmos
    fi
    sudo ln -s "$REPO_DIR_ABS/orgmos" /usr/local/bin/orgmos
    echo -e "${GREEN}✓ Symlink creado${NC}"
fi

echo
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ¡Instalación completada!            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo
echo -e "${BLUE}Ejecuta:${NC} orgmos menu"
echo -e "${BLUE}O visita:${NC} $REPO_DIR"
echo

