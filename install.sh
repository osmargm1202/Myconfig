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
    local gum_color="33"

    case "$level" in
        success) color="$GREEN"; gum_color="42" ;;
        warn)    color="$YELLOW"; gum_color="214" ;;
        error)   color="$RED"; gum_color="204" ;;
        info|*)  color="$CYAN"; gum_color="39" ;;
    esac

    if command -v gum >/dev/null 2>&1; then
        gum style --border normal --border-foreground "$gum_color" --padding "0 1" --foreground "$gum_color" "$message"
    else
        echo -e "${color}${message}${NC}"
    fi
}

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
    log_status info "Repositorio detectado, verificando estado local..."
    cd "$REPO_DIR"

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if [ -n "$(git status --porcelain)" ]; then
            log_status warn "Estás en el proyecto madre con cambios locales sin comprometer. Haz commit/push antes de actualizar."
            log_status warn "Se omitió git pull para no sobrescribir tu trabajo local."
        else
            BEFORE_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "desconocido")
            if pull_output=$(git pull --ff-only 2>&1); then
                AFTER_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "desconocido")
                if [ "$BEFORE_COMMIT" = "$AFTER_COMMIT" ]; then
                    log_status success "Repositorio ya estaba al día (commit $AFTER_COMMIT)."
                else
                    log_status success "Repositorio actualizado de $BEFORE_COMMIT a $AFTER_COMMIT."
                    [ -n "$pull_output" ] && echo "$pull_output"
                fi
            else
                log_status error "No se pudo actualizar el repositorio automáticamente:"
                [ -n "$pull_output" ] && echo "$pull_output"
                log_status error "Revisa la conexión o resuelve los conflictos y vuelve a ejecutar el script."
            fi
        fi
    else
        log_status warn "Directorio existente, pero no es un repositorio Git válido. Se continuará sin actualizar."
    fi
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

