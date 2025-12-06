#!/usr/bin/env bash

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_status() {
    local level="$1"; shift
    local message="$*"
    local color="$BLUE"

    case "$level" in
        success) color="$GREEN" ;;
        warn)    color="$YELLOW" ;;
        error)   color="$RED" ;;
        info|*)  color="$CYAN" ;;
    esac

    echo -e "${color}${message}${NC}"
}

BIN_URL="https://custom.or-gm.com/orgmos"
BIN_DIR="$HOME/.local/bin"
TMP_BIN="/tmp/orgmos_install"

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      ORGMOS Installation Script       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo

# Crear directorio de binarios
mkdir -p "$BIN_DIR"

# Descargar binario
log_status info "Descargando orgmos..."

if command -v curl >/dev/null 2>&1; then
    if curl -fsSL "$BIN_URL" -o "$TMP_BIN"; then
        log_status success "Binario descargado correctamente"
    else
        log_status error "Error al descargar el binario desde $BIN_URL"
        exit 1
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -q "$BIN_URL" -O "$TMP_BIN"; then
        log_status success "Binario descargado correctamente"
    else
        log_status error "Error al descargar el binario desde $BIN_URL"
        exit 1
    fi
else
    log_status error "Se requiere curl o wget para descargar el binario"
    exit 1
fi

# Copiar binario a destino
log_status info "Instalando orgmos..."
chmod +x "$TMP_BIN"
mv "$TMP_BIN" "$BIN_DIR/orgmos"
log_status success "orgmos instalado correctamente en $BIN_DIR/orgmos"

# Crear desktop entry
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/orgmos.desktop << 'EOF'
[Desktop Entry]
Name=ORGMOS
Comment=Sistema de configuración ORGMOS
Exec=orgmos menu
Terminal=true
Type=Application
Icon=orgmos
Categories=System;Utility;
EOF
chmod +x ~/.local/share/applications/orgmos.desktop
log_status success "Desktop entry creado"

# Verificar PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    log_status warn "\$HOME/.local/bin no está en PATH. Agrégalo a tu shell profile:"
    echo -e "${YELLOW}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
fi

echo
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ¡Instalación completada!            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo
echo -e "${BLUE}Binario instalado en:${NC} $BIN_DIR/orgmos"
echo -e "${BLUE}Ejecuta:${NC} orgmos menu"
echo
