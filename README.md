## Myconfig

Sistema de configuración completo para i3wm, polybar, rofi y aplicaciones web con Tokyo Night theme.

### Instalación Rápida con curl (Una sola línea)

```bash
curl -fsSL https://custom.or-gm.com/arch.sh | bash
```

Este comando descarga y ejecuta automáticamente el instalador, que:

- Clona el repositorio automáticamente
- Muestra el menú de instalación completo
- Detecta si ya existe una copia local del repositorio

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
