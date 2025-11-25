# ORGMOS - Sistema de Configuración para Arch Linux

Sistema de configuración completo para i3wm, Hyprland, polybar, rofi y aplicaciones web con tema Tokyo Night.

## 🚀 Instalación Rápida (Una línea)

```bash
curl -fsSL https://raw.githubusercontent.com/osmargm1202/Myconfig/master/install.sh | bash
```

Este comando:
- ✅ Clona/actualiza el repositorio en `~/Myconfig`
- ✅ Instala Go si no está disponible
- ✅ Compila el binario `orgmos`
- ✅ Crea symlink en `/usr/local/bin/orgmos`
- ✅ Crea entrada de escritorio

## 📦 Instalación Manual

### 1. Clonar repositorio

```bash
git clone https://github.com/osmargm1202/Myconfig.git ~/Myconfig
cd ~/Myconfig
```

### 2. Instalar dependencias

**Requisitos:**
- Go 1.21+ (se instala automáticamente si falta)
- Git
- Make (opcional, pero recomendado)

**En Arch Linux:**
```bash
sudo pacman -S go git make
```

**En Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install -y golang-go git make
```

### 3. Compilar e instalar

**Importante:** El Makefile se usa con el comando `make`, no ejecutándolo directamente.

```bash
make install
```

O manualmente:
```bash
go build -o orgmos ./cmd/orgmos
sudo ln -s $(pwd)/orgmos /usr/local/bin/orgmos
```

**Nota:** Si ejecutas `./Makefile` directamente, obtendrás errores. Siempre usa `make [target]` (por ejemplo: `make build`, `make install`, `make run`).

## 🎯 Uso

### Menú Interactivo

```bash
orgmos menu
```

### Comandos Disponibles

| Comando | Descripción |
|---------|-------------|
| `orgmos i3` | Instalar i3 Window Manager y componentes |
| `orgmos hyprland` | Instalar Hyprland y componentes Wayland |
| `orgmos niri` | Instalar Niri Window Manager y componentes |
| `orgmos package` | Instalador interactivo de paquetes |
| `orgmos flatpak` | Instalador de aplicaciones Flatpak |
| `orgmos paru` | Instalar Paru AUR Helper |
| `orgmos sddm` | Instalar y configurar SDDM |
| `orgmos config` | Copiar configuraciones a ~/.config |
| `orgmos assets` | Copiar iconos y wallpapers |
| `orgmos arch` | Herramientas de terminal para Arch |
| `orgmos ubuntu` | Herramientas de terminal para Ubuntu |
| `orgmos script [cmd]` | Ejecutar scripts de automatización |
| `orgmos webapp` | WebApp Creator |
| `orgmos menu` | Menú interactivo principal |

### Ejemplos

```bash
# Instalar i3 completo
orgmos i3

# Instalar Hyprland
orgmos hyprland

# Instalar Niri
orgmos niri

# Instalar paquetes interactivamente
orgmos package

# Instalar Paru AUR Helper
orgmos paru

# Copiar todas las configuraciones
orgmos config

# Copiar iconos y wallpapers
orgmos assets

# Ejecutar script de modo juego
orgmos script game-mode
```

## 📁 Estructura del Proyecto

```
Myconfig/
├── cmd/orgmos/          # Código fuente Go
├── internal/            # Módulos internos
│   ├── ui/             # Estilos y UI
│   ├── packages/       # Gestión de paquetes
│   ├── logger/         # Sistema de logs
│   └── utils/          # Utilidades
├── configs/            # Archivos TOML de paquetes
│   ├── pkg_general.toml
│   ├── pkg_i3.toml
│   ├── pkg_hyprland.toml
│   ├── pkg_niri.toml
│   └── pkg_flatpak.toml
├── configs_to_copy/    # Configuraciones para ~/.config
├── Icons/              # Iconos del sistema
├── Wallpapers/         # Fondos de pantalla
├── sddm/               # Tema SDDM
└── webapp/             # WebApp Creator
```

## 🔧 Actualización

```bash
cd ~/Myconfig
git pull origin master
make install
```

El binario se actualiza automáticamente al ejecutar cualquier comando.

## 📝 Logs

Los logs se guardan en `~/.orgmoslog/` con formato:
```
orgmos-{comando}-{timestamp}.log
```

## 🎨 Características

- ✅ **Interfaz moderna** con Huh y Lipgloss
- ✅ **Colores personalizados** (azul, verde, amarillo, rojo)
- ✅ **Instalación interactiva** por grupos
- ✅ **Detección automática** de paquetes instalados
- ✅ **Preselección inteligente** - paquetes instalados aparecen marcados
- ✅ **Soporte AUR** con Paru
- ✅ **Gestión de Flatpak**
- ✅ **Logs automáticos** de todas las operaciones
- ✅ **Sin confirmaciones excesivas** - UI simple y directa

## 🛠️ Desarrollo

### Compilar

```bash
make build
```

### Ejecutar sin instalar

```bash
make run
# o
go run ./cmd/orgmos menu
```

### Limpiar

```bash
make clean
```

## 📋 Requisitos del Sistema

- **Sistema**: Arch Linux (o basado en Arch)
- **WM**: i3-gaps, Hyprland o Niri
- **Fuentes**: JetBrainsMono Nerd Font
- **Terminal**: kitty o alacritty
- **Launcher**: rofi o wofi

## 🎯 Comandos de Scripts

Los scripts de automatización están disponibles vía `orgmos script`:

- `orgmos script game-mode` - Activar/desactivar modo juego
- `orgmos script caffeine` - Prevenir suspensión
- `orgmos script wallpaper` - Cambiar wallpaper
- `orgmos script display` - Gestión de monitores (rofi)
- `orgmos script lock` - Bloquear pantalla
- `orgmos script powermenu` - Menú de energía

## 🔐 Paru AUR Helper

Paru es necesario para instalar paquetes desde AUR. El sistema lo detecta automáticamente y ofrece instalarlo si falta:

```bash
orgmos paru
```

O se instalará automáticamente cuando sea necesario al ejecutar `orgmos package` o `orgmos arch`.

## 📄 Licencia

Este proyecto es de uso personal. Siéntete libre de usarlo como base para tus propias configuraciones.

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:
1. Fork el repositorio
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

---

**Nota**: Este proyecto reemplaza los scripts bash anteriores con un binario Go más robusto y mantenible.
