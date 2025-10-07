#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1091
#|---/ /+----------------------------------------+---/ /|#
#|--/ /-| Script to install npm packages        |--/ /-|#
#|/ /---+----------------------------------------+/ /---|#

scrDir=$(dirname "$(realpath "$0")")
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

export log_section="npm"

# Verificar si npm está instalado
if ! command -v npm &>/dev/null; then
    print_log -r "[error] " "npm no está instalado. Instala nodejs primero."
    exit 1
fi

print_log -g "[info] " "npm versión: $(npm --version)"
echo ""

# Lista de paquetes npm a instalar globalmente
npm_packages=(
    "@anthropic-ai/claude-code"  # Claude CLI - AI assistant
)

# Verificar e instalar cada paquete
for pkg in "${npm_packages[@]}"; do
    pkg_name="${pkg##*/}"  # Extraer nombre del paquete
    
    if npm list -g "${pkg}" &>/dev/null; then
        print_log -y "[skip] " "${pkg}" -y " (ya instalado)"
    else
        print_log -b "[install] " "${pkg}"
        if sudo npm install -g "${pkg}"; then
            print_log -g "[success] " "${pkg}"
        else
            print_log -r "[error] " "falló la instalación de ${pkg}"
        fi
    fi
done

echo ""
print_log -g "[done] " "Instalación de paquetes npm completada"

