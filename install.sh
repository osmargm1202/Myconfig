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

REPO_URL="https://github.com/osmargm1202/Myconfig.git"
REPO_DIR="$HOME/Myconfig"
BIN_DIR="$HOME/.local/bin"
CURRENT_DIR="$(pwd)"

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      ORGMOS Installation Script       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo

# Verificar si estamos ejecutando desde un repositorio git
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_status info "Repositorio Git detectado en el directorio actual, actualizando..."
    
    # Verificar si hay cambios locales
    if [ -n "$(git status --porcelain)" ]; then
        log_status warn "Cambios locales detectados. Se omite git pull."
    else
        BEFORE_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "desconocido")
        if pull_output=$(git pull --ff-only 2>&1); then
            AFTER_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "desconocido")
            if [ "$BEFORE_COMMIT" = "$AFTER_COMMIT" ]; then
                log_status success "Repositorio ya estaba al día (commit $AFTER_COMMIT)."
            else
                log_status success "Repositorio actualizado de $BEFORE_COMMIT a $AFTER_COMMIT."
            fi
        else
            log_status warn "No se pudo actualizar el repositorio (puede ser normal si no hay conexión)."
        fi
    fi
    
    # Usar el directorio actual como REPO_DIR
    REPO_DIR="$CURRENT_DIR"
else
    # Si no estamos en un repo, clonar o actualizar en ~/Myconfig
    if [ -d "$REPO_DIR" ]; then
        log_status info "Repositorio detectado en $REPO_DIR, actualizando..."
        cd "$REPO_DIR"

        if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            if [ -n "$(git status --porcelain)" ]; then
                log_status warn "Cambios locales detectados. Se omite git pull."
            else
                BEFORE_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "desconocido")
                if pull_output=$(git pull --ff-only 2>&1); then
                    AFTER_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "desconocido")
                    if [ "$BEFORE_COMMIT" = "$AFTER_COMMIT" ]; then
                        log_status success "Repositorio ya estaba al día (commit $AFTER_COMMIT)."
                    else
                        log_status success "Repositorio actualizado de $BEFORE_COMMIT a $AFTER_COMMIT."
                    fi
                else
                    log_status error "No se pudo actualizar el repositorio."
                fi
            fi
        else
            log_status warn "Directorio existente pero no es un repositorio Git válido."
        fi
    else
        log_status info "Clonando repositorio..."
        git clone "$REPO_URL" "$REPO_DIR"
        cd "$REPO_DIR"
    fi
fi

# Crear directorio de binarios
mkdir -p "$BIN_DIR"

# Cambiar al directorio del repositorio
cd "$REPO_DIR"

# Copiar binario orgmos (precompilado)
log_status info "Instalando orgmos..."

if [ -f "$REPO_DIR/orgmos" ]; then
    cp "$REPO_DIR/orgmos" "$BIN_DIR/orgmos"
    chmod +x "$BIN_DIR/orgmos"
    log_status success "orgmos instalado correctamente"
else
    log_status error "Binario orgmos no encontrado en $REPO_DIR"
    log_status error "Asegúrate de que el binario precompilado existe en el repositorio."
    exit 1
fi

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
