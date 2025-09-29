# Qué son estos dotfiles / “Myconfig”

Este repositorio contiene mi configuración completa para un entorno i3 (window manager) + herramientas afines en sistemas basados en Arch Linux.
Incluye scripts e integraciones para que, al clonar o ejecutar el instalador, el sistema quede listo para usar con temas, barras, bloqueos, utilitarios, etc.

## Funcionalidades principales

Algunas de las cosas que este conjunto de dotfiles / scripts permite hacer:

## Módulo / Componente Qué hace / qué configura

**install.sh** Instalador simple: descarga/actualiza repositorio y ejecuta setup.sh (compatible con curl).
**setup.sh** Configurador completo: menú interactivo con Gum, instaladores modulares, todas las opciones.
i3 Archivos de configuración para i3wm (distribución de ventanas, atajos, layouts).
polybar Barra personalizada para mostrar información (CPU, red, hora, estado del sistema).
rofi Menús visuales, launcher de aplicaciones, selector de ventanas.
picom Compositor para sombras, transparencia, efectos visuales.
kitty Configuración del emulador de terminal.
dunst Notificaciones visuales y estéticas.
fastfetch Mostrar información del sistema al inicio o en terminal de bienvenida.
**Wallpapers** Fondos de pantalla aleatorios para i3WM con sistema de memoria y atajo Super+Alt+Space.
Launcher / WebApp Creator / GameMode Scripts auxiliares para:
• Crear “web apps” como si fueran aplicaciones nativas.
• Activar modo de optimización para juegos.
• Un lanzador personalizado de scripts/aplicaciones.
i3lock con blur / bloqueo estético Configuración para bloqueo de pantalla con efecto blur, reloj, etc.

# Myconfig

Sistema de configuración completo para i3wm, polybar, rofi y aplicaciones web con Tokyo Night theme.

### Instalación Rápida con curl (Una sola línea)

```bash
curl -fsSL https://raw.githubusercontent.com/osmargm1202/Myconfig/master/install.sh | bash -x

```

```bash
curl -fsSL https://custom.or-gm.com/arch.sh | bash
```

Este comando ejecuta el instalador en dos fases:

**Fase 1 (install.sh):**
- Descarga/actualiza el repositorio en ~/Myconfig
- Es simple y compatible con curl | bash  
- No requiere TTY ni dependencias complejas

**Fase 2 (setup.sh):**
- Muestra menú interactivo con interfaz moderna (Gum)
- Instaladores modulares organizados en Apps/
- Opciones: WebApp Creator, SDDM, Plymouth, Wallpapers, etc.
- Colores azul cielo y navegación con flechas

### Instalación Automática (Método tradicional)

```bash
git clone https://github.com/osmargm1202/Myconfig.git
cd Myconfig
chmod +x install.sh
./install.sh
```

El instalador incluye las siguientes opciones:

- **Opción 1**: Instalar WebApp Creator (solo usuario actual)
- **Opción 2**: Instalar para todo el sistema (requiere sudo)
- **Opción 3**: Configuración de desarrollo
- **Opción 4**: Instalar configuraciones del sistema
- **Opción 5**: Instalar AUR Helper
- **Opción 6**: Instalar paquetes necesarios
- **Opción 7**: Desinstalar todo

### Instalación Manual

#### 1. Clonar repositorio

```bash
git clone https://github.com/osmargm1202/Myconfig.git
cd Myconfig
```

#### 2. Instalar dependencias

```bash
# Para el AUR helper (yay)
chmod +x Apps/install_aur.sh
./Apps/install_aur.sh

# Para los paquetes del sistema
chmod +x Apps/install_pkg.sh
./Apps/install_pkg.sh
```

#### 3. Copiar configuraciones

```bash
cp -r i3 ~/.config/
cp -r polybar ~/.config/
cp -r rofi ~/.config/
cp -r picom ~/.config/
cp -r kitty ~/.config/
cp -r dunst ~/.config/
cp -r fastfetch ~/.config/
cp -r kvantum ~/.config/
```

#### 4. Configurar WebApp Creator y GameMode

```bash
mkdir -p ~/.local/bin
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc

# Copiar scripts
cp Launcher/webapp-creator.sh ~/.local/bin/webapp-creator
cp Launcher/launcher.sh ~/.local/bin/
cp Launcher/game-mode.sh ~/.local/bin/
chmod +x ~/.local/bin/*
```

### Comandos Importantes

#### Polybar

```bash
# Iniciar polybar
polybar modern &

# Reiniciar polybar
pkill polybar && polybar modern &
```

#### i3lock (requiere i3lock-color)

```bash
# Instalar i3lock-color desde AUR
yay -S i3lock-color

# Usar comando de bloqueo
i3lock --blur 5 --clock --date-str "%A, %B %d" --time-str "%I:%M %p"
```

#### WebApp Creator

```bash
# Crear nueva webapp
webapp-creator

# Launcher con aplicaciones
launcher.sh

# Activar modo gaming
game-mode.sh
```

### Actualizaciones

```bash
cd Myconfig
git pull origin master
cp -r ./* ~/.config/
# Reiniciar i3: Mod+Shift+R
```

## 🚀 Funcionalidades Modernas

### 🎨 Interfaz Visual con Gum
- **Menús interactivos** con navegación de flechas
- **Colores azul cielo** personalizados  
- **Confirmaciones visuales** estilo moderno
- **Fallback automático** a interfaz clásica

### 🖼️ Sistema de Wallpapers Inteligente
- **Copia automática** de wallpapers a ~/Wallpapers
- **Wallpaper aleatorio** al iniciar i3 (recordado entre sesiones)
- **Atajo Super+Alt+Space** para cambiar wallpaper
- **Sistema de memoria** mantiene último wallpaper usado

### 🎭 Temas de Arranque y Login
- **SDDM Theme Corners** con configuración automática de /etc/sddm.conf
- **Plymouth Themes** con 11 temas curados y logo de Arch Linux
- **Autologin opcional** para SDDM

### 📦 Instaladores Modulares
- **install_configs.sh** - Configuraciones del sistema
- **install_webapp.sh** - WebApp Creator completo
- **install_sddm.sh** - Tema de login SDDM
- **install_plymouth.sh** - Temas de arranque Plymouth  
- **install_wallpapers.sh** - Sistema de fondos de pantalla
- **install_aur.sh** - AUR helper
- **install_pkg.sh** - Paquetes del sistema

### Requisitos del Sistema

- **Sistema**: Arch Linux (o basado en Arch)
- **WM**: i3-gaps
- **Fuentes**: JetBrainsMono Nerd Font
- **Compositor**: picom
- **Terminal**: kitty
- **Launcher**: rofi
- **Bar**: polybar

### Características

- **Tema**: Tokyo Night con transparencias
- **Power Menu**: Botones de apagar, suspender y bloquear en polybar
- **WebApp Creator**: Crear aplicaciones web como apps nativas
- **Game Mode**: Optimización para juegos
- **i3lock**: Bloqueo con blur y transparencia
- **Configuración completa**: Todo listo para usar
