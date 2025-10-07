#!/bin/bash

# Script para instalar aplicaciones Flatpak desde un archivo de lista
# Uso: ./install_flatpaks.sh [archivo_lista]

# No usar set -e porque queremos manejar errores individualmente por app

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin color

# Archivo de lista por defecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LISTA="${1:-$SCRIPT_DIR/pkg_flatpak.lst}"

# Verificar si flatpak está instalado
if ! command -v flatpak &> /dev/null; then
    echo -e "${RED}Error: Flatpak no está instalado${NC}"
    exit 1
fi

# Verificar si existe el archivo de lista
if [ ! -f "$LISTA" ]; then
    echo -e "${RED}Error: No se encuentra el archivo $LISTA${NC}"
    exit 1
fi

# Agregar repositorio Flathub si no está
echo -e "${YELLOW}Verificando repositorio Flathub...${NC}"
if ! flatpak remote-list | grep -q flathub; then
    echo "Agregando repositorio Flathub..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

echo -e "${GREEN}Iniciando instalación de aplicaciones...${NC}\n"

# Contador de apps
total=0
instaladas=0
actualizadas=0
errores=0

# Leer archivo línea por línea
while IFS= read -r linea || [ -n "$linea" ]; do
    # Ignorar líneas vacías y comentarios
    [[ -z "$linea" || "$linea" =~ ^[[:space:]]*# ]] && continue
    
    ((total++))
    
    # Extraer ID de la aplicación (eliminar espacios)
    app_id=$(echo "$linea" | xargs)
    
    echo -e "${YELLOW}[$total] Procesando: $app_id${NC}"
    
    # Verificar si ya está instalada
    if flatpak list --app 2>/dev/null | grep -q "$app_id"; then
        echo -e "${YELLOW}  Ya instalada, actualizando...${NC}"
        if flatpak update -y "$app_id" &>/dev/null; then
            echo -e "${GREEN}✓ Actualizada exitosamente${NC}\n"
            ((actualizadas++))
        else
            echo -e "${RED}✗ Error al actualizar${NC}\n"
            ((errores++))
        fi
    else
        # Intentar instalar
        echo -e "  Instalando desde Flathub..."
        if flatpak install -y flathub "$app_id" &>/dev/null; then
            echo -e "${GREEN}✓ Instalada exitosamente${NC}\n"
            ((instaladas++))
        else
            echo -e "${RED}✗ Error al instalar${NC}\n"
            ((errores++))
        fi
    fi
    
done < "$LISTA"

# Resumen
echo -e "\n${GREEN}========== RESUMEN ==========${NC}"
echo -e "Total procesadas: $total"
echo -e "${GREEN}Instaladas: $instaladas${NC}"
echo -e "${YELLOW}Actualizadas: $actualizadas${NC}"
echo -e "${RED}Errores: $errores${NC}"
echo -e "${GREEN}=============================${NC}"

exit 0