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
• Crear "web apps" como si fueran aplicaciones nativas.
• Activar modo de optimización para juegos.
• Un lanzador personalizado de scripts/aplicaciones.
**System76 Power** Gestión avanzada de energía con:
• Daemon de optimización de batería.
• Interfaz gráfica para perfiles de energía.
• Click en icono de batería en polybar para acceso rápido.
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

- **Opción 1**: Instalación Completa Automática
- **Opción 2**: Instalar WebApp Creator + System Configs
- **Opción 3**: Instalar AUR Helper
- **Opción 4**: Instalar Paquetes
- **Opción 5**: Instalar SDDM Theme (Corners)
- **Opción 6**: Instalar Plymouth Themes
- **Opción 7**: Setup Wallpapers
- **Opción 8**: Instalar System76 Power - Gestión de energía
- **Opción 9**: Desinstalar todo
- **Opción 10**: Salir

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

#### System76 Power

```bash
# Instalar System76 Power
./Apps/install_system76.sh

# Abrir interfaz gráfica
system76-power-gui-x11

# Ver estado actual de energía
system76-power profile

# Cambiar perfil de energía (battery/balanced/performance)
system76-power profile battery
system76-power profile balanced
system76-power profile performance
```

**Características:**
- Click en el icono de batería en polybar para abrir la GUI
- Daemon se inicia automáticamente con i3
- Gestión inteligente de energía para laptops
- Perfiles optimizados para batería/rendimiento

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
- **install_npm.sh** - Paquetes npm globales (Claude CLI, etc.)

### 🤖 Herramientas de IA y Desarrollo

El sistema incluye **Claude CLI** (@anthropic-ai/claude-code) instalado globalmente vía npm.

#### Instalación Manual de Paquetes npm

```bash
# Ejecutar el instalador de npm (requiere nodejs y npm)
chmod +x Apps/install_npm.sh
./Apps/install_npm.sh
```

Los paquetes npm están listados en `Apps/pkg_npm.lst` y se instalan automáticamente con la opción de instalación completa.

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
