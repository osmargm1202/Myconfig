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
  
  selected=$(printf '%s\n' "${themes[@]}" | gum choose --header "🎨 Selecciona un tema de Plymouth" --height 15 < /dev/tty)
  
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
    echo -e "${BLUE}Instalando Plymouth base...${NC}"
    if sudo pacman -S plymouth --noconfirm; then
      echo -e "${GREEN}✓ Plymouth instalado${NC}"
    else
      echo -e "${RED}✗ Error al instalar Plymouth${NC}"
      return 1
    fi
  else
    echo -e "${GREEN}✓ Plymouth ya está instalado${NC}"
  fi
  return 0
}

# Function to install selected theme
install_theme() {
  local theme_name="$1"
  local package_name="plymouth-theme-$theme_name-git"
  
  echo -e "${BLUE}Instalando tema: $theme_name${NC}"
  echo -e "${BLUE}Paquete: $package_name${NC}"
  echo
  
  # Check if AUR helper is available
  local aur_helper=""
  if command -v yay &>/dev/null; then
    aur_helper="yay"
  elif command -v paru &>/dev/null; then
    aur_helper="paru"
  else
    echo -e "${RED}✗ Se requiere un AUR helper (yay o paru) para instalar temas de Plymouth${NC}"
    echo -e "${YELLOW}Instala yay o paru primero${NC}"
    return 1
  fi
  
  # Install from AUR with -git suffix (all Plymouth themes use -git)
  echo -e "${BLUE}Instalando desde AUR...${NC}"
  echo -e "${YELLOW}Se te pedirá confirmación y contraseña si es necesario${NC}"
  echo
  
  if $aur_helper -S "$package_name"; then
    echo -e "${GREEN}✓ Tema $theme_name instalado desde AUR${NC}"
  else
    echo -e "${RED}✗ Error al instalar tema $theme_name${NC}"
    echo -e "${YELLOW}Verifica que el tema exista en AUR: $package_name${NC}"
    return 1
  fi
  
  return 0
}

# Function to customize theme with Arch Linux logo
customize_theme() {
  local theme_name="$1"
  local repo_dir="${2:-$HOME/Myconfig}"
  # Convert theme name from dash to underscore for directory name
  local theme_dir_name="${theme_name//-/_}"
  local theme_dir="/usr/share/plymouth/themes/$theme_dir_name"
  local arch_image="$repo_dir/Apps/archlinux.png"
  local plymouth_code="$repo_dir/Apps/plymouth.md"
  
  echo -e "${BLUE}Personalizando tema con logo de Arch Linux...${NC}"
  echo -e "${BLUE}Buscando directorio: $theme_dir${NC}"
  
  # Check if theme directory exists
  if [[ ! -d "$theme_dir" ]]; then
    echo -e "${YELLOW}⚠ Directorio del tema no encontrado: $theme_dir${NC}"
    echo -e "${BLUE}Intentando encontrar el tema instalado...${NC}"
    
    # Try to find theme directory with different naming patterns
    local found_theme_dir=""
    for pattern in "$theme_name" "$theme_dir_name" "${theme_name//-/}"; do
      found_theme_dir=$(find /usr/share/plymouth/themes/ -name "*$pattern*" -type d 2>/dev/null | head -1)
      if [[ -n "$found_theme_dir" ]]; then
        break
      fi
    done
    
    if [[ -n "$found_theme_dir" ]]; then
      theme_dir="$found_theme_dir"
      echo -e "${GREEN}✓ Tema encontrado en: $theme_dir${NC}"
    else
      echo -e "${RED}✗ No se pudo encontrar el directorio del tema${NC}"
      echo -e "${YELLOW}Directorios disponibles en /usr/share/plymouth/themes/:${NC}"
      ls -la /usr/share/plymouth/themes/ 2>/dev/null || true
      return 1
    fi
  fi
  
  # Check if arch image exists
  if [[ ! -f "$arch_image" ]]; then
    echo -e "${YELLOW}⚠ Imagen archlinux.png no encontrada en: $arch_image${NC}"
    echo -e "${BLUE}Saltando personalización de imagen...${NC}"
  else
    # Copy arch image to theme directory
    echo -e "${BLUE}Copiando imagen de Arch Linux...${NC}"
    if sudo cp "$arch_image" "$theme_dir/"; then
      echo -e "${GREEN}✓ Imagen copiada a: $theme_dir/archlinux.png${NC}"
    else
      echo -e "${RED}✗ Error al copiar imagen${NC}"
      return 1
    fi
  fi
  
  # Check if plymouth code exists
  if [[ ! -f "$plymouth_code" ]]; then
    echo -e "${YELLOW}⚠ Código Plymouth no encontrado en: $plymouth_code${NC}"
    echo -e "${BLUE}Saltando modificación del script...${NC}"
  else
    # Find the theme script file
    local script_file=$(find "$theme_dir" -name "*.script" | head -1)
    if [[ -z "$script_file" ]]; then
      echo -e "${YELLOW}⚠ Archivo .script no encontrado en el tema${NC}"
      echo -e "${BLUE}Saltando modificación del script...${NC}"
    else
      echo -e "${BLUE}Modificando script del tema: $(basename "$script_file")${NC}"
      
      # Create backup of original script
      sudo cp "$script_file" "$script_file.backup.$(date +%Y%m%d_%H%M%S)"
      echo -e "${GREEN}✓ Backup del script creado${NC}"
      
      # Append arch linux code to script
      echo -e "${BLUE}Agregando código de Arch Linux al script...${NC}"
      sudo tee -a "$script_file" > /dev/null << 'EOF'

# Arch Linux Logo Integration
EOF
      sudo cat "$plymouth_code" | sudo tee -a "$script_file" > /dev/null
      
      if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Código agregado al script del tema${NC}"
      else
        echo -e "${RED}✗ Error al modificar script del tema${NC}"
        return 1
      fi
    fi
  fi
  
  echo -e "${GREEN}✓ Personalización del tema completada${NC}"
  return 0
}

# Function to set default theme
set_default_theme() {
  local theme_name="$1"
  # Convert theme name to directory name (dash to underscore)
  local theme_dir_name="${theme_name//-/_}"
  
  echo -e "${BLUE}Configurando $theme_dir_name como tema por defecto...${NC}"
  
  if sudo plymouth-set-default-theme -R "$theme_dir_name"; then
    echo -e "${GREEN}✓ Tema $theme_dir_name configurado como por defecto${NC}"
    echo -e "${BLUE}Se regeneró la imagen initramfs${NC}"
  else
    echo -e "${RED}✗ Error al configurar tema por defecto${NC}"
    echo -e "${YELLOW}Intentando con nombre original: $theme_name${NC}"
    
    # Fallback: try with original name
    if sudo plymouth-set-default-theme -R "$theme_name"; then
      echo -e "${GREEN}✓ Tema $theme_name configurado como por defecto${NC}"
      echo -e "${BLUE}Se regeneró la imagen initramfs${NC}"
    else
      echo -e "${RED}✗ Error al configurar tema por defecto${NC}"
      echo -e "${YELLOW}Puedes intentar manualmente:${NC}"
      echo -e "${WHITE}  sudo plymouth-set-default-theme -R $theme_dir_name${NC}"
      echo -e "${WHITE}  sudo plymouth-set-default-theme -R $theme_name${NC}"
      return 1
    fi
  fi
  
  return 0
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
  show_header
  check_root
  
  echo -e "${WHITE}Este script te ayudará a:${NC}"
  echo -e "${BLUE}  1. Seleccionar de una lista curada de temas Plymouth${NC}"
  echo -e "${BLUE}  2. Instalar el tema seleccionado desde AUR${NC}"
  echo -e "${BLUE}  3. Personalizarlo con el logo de Arch Linux${NC}"
  echo -e "${BLUE}  4. Configurarlo como tema por defecto${NC}"
  echo -e "${BLUE}  5. Regenerar initramfs automáticamente${NC}"
  echo
  
  # Skip interactive menu - go straight to automatic installation
  echo -e "${GREEN}✓ Iniciando instalación automática${NC}"
  
  echo
  
  # Install Plymouth base if needed
  echo -e "${BLUE}Verificando instalación de Plymouth...${NC}"
  if ! install_plymouth_base; then
    exit 1
  fi
  
  echo
  echo -e "${BLUE}Cargando lista de temas disponibles...${NC}"
  
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
  
  echo -e "${GREEN}✓ ${#themes_array[@]} temas cargados${NC}"
  echo
  
  # Use default theme instead of interactive selection
  local theme_name="colorful-loop"
  echo -e "${GREEN}✓ Tema seleccionado automáticamente: $theme_name${NC}"
  
  echo
  echo -e "${GREEN}Tema seleccionado: $theme_name${NC}"
  echo
  
  # Install selected theme
  if ! install_theme "$theme_name"; then
    exit 1
  fi
  
  echo
  
  # Customize theme with Arch Linux logo
  local repo_dir="${1:-$HOME/Myconfig}"
  if ! customize_theme "$theme_name" "$repo_dir"; then
    echo -e "${YELLOW}⚠ Personalización falló, pero el tema se instaló correctamente${NC}"
  fi
  
  echo
  
  # Set as default theme
  if ! set_default_theme "$theme_name"; then
    exit 1
  fi
  
  # Show completion with the actual configured theme name
  local configured_theme_name="${theme_name//-/_}"
  show_completion "$configured_theme_name"
}

# Run main function
main "$@"

# Wait for user input before returning to menu
echo
if [[ -c /dev/tty ]]; then
  read -p "Presiona Enter para volver al menú principal..." </dev/tty
else
  read -p "Presiona Enter para volver al menú principal..."
fi
