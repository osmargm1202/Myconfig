#!/usr/bin/env bash

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directorios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY_NAME="orgmos_pacman"
DESKTOP_FILE="orgmos_pacman.desktop"

# Rutas de instalación
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
DESKTOP_DIR="${DESKTOP_DIR:-$HOME/.local/share/applications}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  ORGMOS Gestor de Paquetes - Instalador${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar que Go esté instalado
if ! command -v go &> /dev/null; then
    echo -e "${RED}Error: Go no está instalado${NC}"
    echo -e "${YELLOW}Por favor instala Go primero${NC}"
    exit 1
fi

echo -e "${GREEN}[1/5]${NC} Compilando binario..."
cd "$PROJECT_DIR"
if go build -o "$BINARY_NAME" .; then
    echo -e "${GREEN}✓ Binario compilado exitosamente${NC}"
else
    echo -e "${RED}✗ Error al compilar el binario${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}[2/5]${NC} Creando directorios de instalación..."
mkdir -p "$BIN_DIR"
mkdir -p "$DESKTOP_DIR"
echo -e "${GREEN}✓ Directorios creados${NC}"

echo ""
echo -e "${GREEN}[3/5]${NC} Instalando binario en $BIN_DIR..."
if cp "$PROJECT_DIR/$BINARY_NAME" "$BIN_DIR/$BINARY_NAME"; then
    chmod +x "$BIN_DIR/$BINARY_NAME"
    echo -e "${GREEN}✓ Binario instalado en $BIN_DIR/$BINARY_NAME${NC}"
else
    echo -e "${RED}✗ Error al instalar el binario${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}[4/5]${NC} Instalando archivo .desktop en $DESKTOP_DIR..."
# Actualizar la ruta del ejecutable en el archivo .desktop
sed "s|^Exec=.*|Exec=$BIN_DIR/$BINARY_NAME|" "$PROJECT_DIR/$DESKTOP_FILE" > "$DESKTOP_DIR/$DESKTOP_FILE"
chmod +x "$DESKTOP_DIR/$DESKTOP_FILE"
echo -e "${GREEN}✓ Archivo .desktop instalado${NC}"

echo ""
echo -e "${GREEN}[5/5]${NC} Verificando instalación..."
if [ -f "$BIN_DIR/$BINARY_NAME" ] && [ -x "$BIN_DIR/$BINARY_NAME" ]; then
    echo -e "${GREEN}✓ Instalación completada exitosamente${NC}"
else
    echo -e "${RED}✗ Error en la verificación${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Instalación completada${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Binario instalado en: ${YELLOW}$BIN_DIR/$BINARY_NAME${NC}"
echo -e "Archivo .desktop en: ${YELLOW}$DESKTOP_DIR/$DESKTOP_FILE${NC}"
echo ""
echo -e "${YELLOW}Nota:${NC} Asegúrate de que $BIN_DIR está en tu PATH"
echo -e "Puedes ejecutar el gestor con: ${GREEN}$BINARY_NAME${NC}"
echo ""



