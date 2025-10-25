#!/usr/bin/env bash

# Plymouth Theme Installer
# Searches and installs Plymouth themes dynamically

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Check if Gum is available (REQUIRED)
if ! command -v gum &>/dev/null; then
  echo -e "${RED}✗ Este script requiere 'gum' para funcionar${NC}"
  echo -e "${YELLOW}Instala gum primero:${NC}"
  echo -e "${BLUE}  yay -S gum${NC}"
  echo -e "${BLUE}  # o${NC}"
  echo -e "${BLUE}  paru -S gum${NC}"
  exit 1
fi

# Gum color configuration
export GUM_CHOOSE_SELECTED_FOREGROUND="#87CEEB"  # Sky Blue
export GUM_CHOOSE_CURSOR_FOREGROUND="#00BFFF"    # Deep Sky Blue
export GUM_CONFIRM_SELECTED_FOREGROUND="#87CEEB"
export GUM_INPUT_CURSOR_FOREGROUND="#00BFFF"
export GUM_INPUT_PROMPT_FOREGROUND="#87CEEB"

# Function to ask for confirmation (uses gum)
ask_confirmation() {
  local message="$1"
  gum confirm "$message" < /dev/tty
  return $?
}

# Function to display header
show_header() {
  clear
  echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║       Plymouth Theme Installer         ║${NC}"
  echo -e "${CYAN}║        Dynamic Theme Search            ║${NC}"
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

# Function to get predefined Plymouth themes list
get_plymouth_themes() {
  # Predefined list of working Plymouth themes
  local themes=(
    "colorful-loop"
    "angular"
    "black-hud"
    "cybernetic"
    "dark-planet"
    "green-blocks"
    "green-loader"
    "optimus"
    "hud-space"
    "loader-alt"
    "target"
  )
  
  printf '%s\n' "${themes[@]}"
  return 0
}

# Function to show theme selection menu (uses gum)
show_theme_menu() {
  local themes=("$@")
  local selected
  
  selected=$(printf '%s\n' "${themes[@]}" | gum choose --header "🎨 Selecciona un tema de Plymouth" --height 15)
  
  if [[ -n "$selected" ]]; then
    echo "$selected"
    return 0
  else
    return 1
  fi
}

# Function to install Plymouth base if not installed
install_plymouth_base() {
  if ! pacman -Qi plymouth &>/dev/null; then
    sudo pacman -S plymouth --noconfirm
  fi
}

# Function to install selected theme
install_theme() {
  local theme_name="$1"
  local package_name="plymouth-theme-$theme_name-git"
  
  # Check if AUR helper is available
  local aur_helper=""
  if command -v yay &>/dev/null; then
    aur_helper="yay"
  elif command -v paru &>/dev/null; then
    aur_helper="paru"
  else
    echo -e "${RED}✗ Se requiere un AUR helper (yay o paru)${NC}"
    return 1
  fi
  
  $aur_helper -S "$package_name" --noconfirm
}

# Function to customize theme with Arch Linux logo
customize_theme() {
  local theme_name="$1"
  local repo_dir="${2:-$HOME/Myconfig}"
  local theme_dir_name="${theme_name//-/_}"
  local theme_dir="/usr/share/plymouth/themes/$theme_dir_name"
  local arch_image="$repo_dir/Apps/archlinux.png"
  local plymouth_code="$repo_dir/Apps/plymouth.md"
  
  # Find theme directory
  if [[ ! -d "$theme_dir" ]]; then
    for pattern in "$theme_name" "$theme_dir_name" "${theme_name//-/}"; do
      theme_dir=$(find /usr/share/plymouth/themes/ -name "*$pattern*" -type d 2>/dev/null | head -1)
      [[ -n "$theme_dir" ]] && break
    done
  fi
  
  # Copy arch image if exists
  if [[ -f "$arch_image" && -d "$theme_dir" ]]; then
    sudo cp "$arch_image" "$theme_dir/"
  fi
  
  # Add arch code to script if exists
  if [[ -f "$plymouth_code" && -d "$theme_dir" ]]; then
    local script_file=$(find "$theme_dir" -name "*.script" | head -1)
    if [[ -n "$script_file" ]]; then
      sudo cp "$script_file" "$script_file.backup.$(date +%Y%m%d_%H%M%S)"
      sudo tee -a "$script_file" > /dev/null << 'EOF'

# Arch Linux Logo Integration
EOF
      sudo cat "$plymouth_code" | sudo tee -a "$script_file" > /dev/null
    fi
  fi
}

# Function to set default theme
set_default_theme() {
  local theme_name="$1"
  local theme_dir_name="${theme_name//-/_}"
  
  sudo plymouth-set-default-theme -R "$theme_dir_name" || sudo plymouth-set-default-theme -R "$theme_name"
}

# Function to show manual configuration instructions
show_manual_instructions() {
  clear
  echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║     Instrucciones de Configuración Manual de Plymouth    ║${NC}"
  echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
  echo
  
  echo -e "${WHITE}Sigue estos pasos para configurar Plymouth manualmente:${NC}"
  echo
  
  # Step 1
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Paso 1: Editar /etc/mkinitcpio.conf${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Comando:${NC}"
  echo -e "${WHITE}  sudo vim /etc/mkinitcpio.conf${NC}"
  echo
  echo -e "${BLUE}Modificación:${NC}"
  echo -e "${WHITE}  Busca la línea que empieza con 'HOOKS=' y agrega 'plymouth' DESPUÉS de 'base udev'${NC}"
  echo
  echo -e "${CYAN}  Ejemplo:${NC}"
  echo -e "${WHITE}  HOOKS=(base udev plymouth autodetect modconf kms keyboard keymap consolefont block filesystems fsck)${NC}"
  echo
  
  # Step 2
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Paso 2: Regenerar initramfs${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Comando:${NC}"
  echo -e "${WHITE}  sudo mkinitcpio -p linux${NC}"
  echo
  echo -e "${CYAN}  Esto regenerará la imagen initramfs con Plymouth incluido${NC}"
  echo
  
  # Step 3
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Paso 3: Editar /etc/default/grub${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Comando:${NC}"
  echo -e "${WHITE}  sudo vim /etc/default/grub${NC}"
  echo
  echo -e "${BLUE}Modificación:${NC}"
  echo -e "${WHITE}  Busca 'GRUB_CMDLINE_LINUX_DEFAULT=' y agrega 'quiet splash'${NC}"
  echo
  echo -e "${CYAN}  Ejemplo:${NC}"
  echo -e "${WHITE}  GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash loglevel=3\"${NC}"
  echo
  
  # Step 4
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Paso 4: Regenerar configuración de GRUB${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Comando:${NC}"
  echo -e "${WHITE}  sudo grub-mkconfig -o /boot/grub/grub.cfg${NC}"
  echo
  
  # Step 5 (Optional)
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Paso 5: (Opcional) Configurar Plymouth${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Comando:${NC}"
  echo -e "${WHITE}  sudo vim /etc/plymouth/plymouthd.conf${NC}"
  echo
  echo -e "${CYAN}  Aquí puedes ajustar configuraciones avanzadas como:${NC}"
  echo -e "${WHITE}  • Theme= (nombre del tema)${NC}"
  echo -e "${WHITE}  • ShowDelay= (retraso antes de mostrar el splash)${NC}"
  echo -e "${WHITE}  • DeviceTimeout= (timeout de dispositivos)${NC}"
  echo
  
  # Final step
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Paso 6: Reiniciar${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${WHITE}  sudo reboot${NC}"
  echo
  
  # Additional commands
  echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║              Comandos Útiles Adicionales                  ║${NC}"
  echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
  echo
  echo -e "${BLUE}Ver temas instalados:${NC}"
  echo -e "${WHITE}  plymouth-set-default-theme --list${NC}"
  echo
  echo -e "${BLUE}Cambiar tema activo:${NC}"
  echo -e "${WHITE}  sudo plymouth-set-default-theme -R [nombre_tema]${NC}"
  echo
  echo -e "${BLUE}Probar Plymouth sin reiniciar:${NC}"
  echo -e "${WHITE}  sudo plymouthd; sudo plymouth --show-splash; sleep 5; sudo plymouth quit${NC}"
  echo
  echo -e "${BLUE}Ver tema actual:${NC}"
  echo -e "${WHITE}  plymouth-set-default-theme${NC}"
  echo
  
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo
}

# Function to show completion message
show_completion() {
  local theme_name="$1"
  
  echo
  echo -e "${GREEN}✓ ¡Tema de Plymouth instalado y configurado!${NC}"
  echo
  echo -e "${WHITE}Configuración:${NC}"
  echo -e "${BLUE}  • Tema activo: $theme_name${NC}"
  echo -e "${BLUE}  • Initramfs regenerado${NC}"
  echo
  echo -e "${YELLOW}Para ver el tema en acción:${NC}"
  echo -e "${BLUE}  • Reinicia tu sistema${NC}"
  echo -e "${BLUE}  • O prueba con: sudo plymouthd; sudo plymouth --show-splash; sudo plymouth quit${NC}"
  echo
  echo -e "${WHITE}Comandos útiles:${NC}"
  echo -e "${BLUE}  • Ver temas disponibles: plymouth-set-default-theme --list${NC}"
  echo -e "${BLUE}  • Cambiar tema: sudo plymouth-set-default-theme -R [nombre]${NC}"
  echo
}

# Main execution
main() {
  check_root
  
  # Check if we're in a real interactive terminal
  if [[ -t 0 && -t 1 && -t 2 ]] && [[ -n "$PS1" || -n "$BASH_VERSION" ]]; then
    # Interactive mode - show menu
    local choice
    choice=$(printf '%s\n' "Instalar tema Plymouth" "Ver instrucciones de configuración manual" "Salir" | gum choose --header "Plymouth Theme Installer")
    
    case "$choice" in
      "Ver instrucciones de configuración manual")
        show_manual_instructions
        exit 0
        ;;
      "Salir")
        exit 0
        ;;
      "Instalar tema Plymouth")
        # Continue with theme selection and installation
        ;;
      *)
        exit 0
        ;;
    esac
  else
    # Non-interactive mode - show error and exit
    echo -e "${RED}Este script requiere un terminal interactivo para funcionar${NC}"
    echo -e "${YELLOW}Ejecuta el script desde un terminal real, no desde un script automatizado${NC}"
    exit 1
  fi
  
  # Load predefined themes into array
  local themes_array=(
    "colorful-loop"
    "angular"
    "black-hud"
    "cybernetic"
    "dark-planet"
    "green-blocks"
    "green-loader"
    "optimus"
    "hud-space"
    "loader-alt"
    "target"
  )
  
  # Show theme selection menu
  local selected_theme
  selected_theme=$(show_theme_menu "${themes_array[@]}")
  
  if [[ -z "$selected_theme" ]]; then
    exit 0
  fi
  
  local theme_name="$selected_theme"
  
  # Install Plymouth base if needed
  if ! install_plymouth_base; then
    exit 1
  fi
  
  # Install selected theme
  if ! install_theme "$theme_name"; then
    exit 1
  fi
  
  # Customize theme with Arch Linux logo
  local repo_dir="${1:-$HOME/Myconfig}"
  customize_theme "$theme_name" "$repo_dir"
  
  # Set as default theme
  if ! set_default_theme "$theme_name"; then
    exit 1
  fi
  
  echo -e "${GREEN}✓ Tema Plymouth instalado: $theme_name${NC}"
}

# Run main function
main "$@"
