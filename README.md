# ORGMOS - Sistema de Configuración para Arch Linux

Sistema de configuración completo para i3wm, Niri, rofi y aplicaciones web con tema Tokyo Night.

## 🚀 Instalación Rápida (Una línea)

```bash
curl -fsSL https://raw.githubusercontent.com/osmargm1202/Myconfig/master/install.sh | bash
```

Este comando:
- ✅ Clona/actualiza el repositorio en `~/Myconfig`
- ✅ Instala Go si no está disponible
- ✅ Descarga e instala los binarios `orgmos` y `orgmai` desde `dist/`
- ✅ Copia binarios a `~/.local/bin/` con permisos de ejecución
- ✅ Crea entrada de escritorio

**Nota:** `install.sh` ya no compila los binarios, solo los descarga desde el repositorio. Para compilar localmente, ver la sección [Builds Manuales](#-builds-manuales).

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

Para compilar los binarios localmente:
```bash
make build
```

Esto compilará ambos binarios (`orgmos` y `orgmai`) en la carpeta `dist/`.

Para instalar después de compilar:
```bash
cp dist/orgmos ~/.local/bin/
cp dist/orgmai ~/.local/bin/
chmod +x ~/.local/bin/orgmos ~/.local/bin/orgmai
```

**Nota:** Si ejecutas `./Makefile` directamente, obtendrás errores. Siempre usa `make [target]` (por ejemplo: `make build`, `make build-orgmos`, `make build-orgmai`).

## 🎯 Uso

### Menú Interactivo

```bash
orgmos menu
```

### Comandos Disponibles

| Comando | Descripción |
|---------|-------------|
| `orgmos i3` | Instalar i3 Window Manager y componentes |
| `orgmos niri` | Instalar Niri Window Manager y componentes |
| `orgmos package` | Instalador interactivo de paquetes |
| `orgmos flatpak` | Instalador de aplicaciones Flatpak |
| `orgmos paru` | Instalar Paru AUR Helper |
| `orgmos sddm` | Instalar y configurar SDDM |
| `orgmos config` | Copiar configuraciones a ~/.config |
| `orgmos assets` | Copiar iconos y wallpapers |
| `orgmos arch` | Herramientas de terminal para Arch |
| `orgmos ubuntu` | Herramientas de terminal para Ubuntu |
| `orgmos update` | Actualizar orgmos y orgmai desde el servidor remoto |
| `orgmos menu` | Menú interactivo principal |

### Ejemplos

```bash
# Instalar i3 completo
orgmos i3

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

# Mostrar atajos de i3
orgmos i3 hotkey
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
│   ├── pkg_niri.toml
│   └── pkg_flatpak.toml
├── configs_to_copy/    # Configuraciones para ~/.config
├── Icons/              # Iconos del sistema
├── Wallpapers/         # Fondos de pantalla
├── sddm/               # Tema SDDM
```

## 🔧 Actualización

### Actualización automática

```bash
orgmos update
```

Este comando ejecuta el script de instalación remoto para actualizar los binarios `orgmos` y `orgmai`.

### Actualización manual

```bash
cd ~/Myconfig
git pull origin master
make build
cp dist/orgmos ~/.local/bin/
cp dist/orgmai ~/.local/bin/
chmod +x ~/.local/bin/orgmos ~/.local/bin/orgmai
```

**Nota:** Los archivos de configuración se descargan automáticamente cuando los comandos los necesitan, usando `~/.config/orgmos/repo/` como caché local.

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

## 🎛️ Shell Wayland (Polybar ➜ DMS Shell)

- DMS Shell replica los módulos críticos de la barra (workspaces, título de ventana, fecha/hora, filesystem, audio, batería, métricas y toggles de hotkeys/powermenu) pero optimizados para Wayland.
- Los atajos `orgmos i3 …` alimentan los módulos personalizados para mantener el flujo de trabajo en i3 y Niri.
- El tema aplica la misma paleta **Tokyo Night** (fondos translúcidos + acentos lila/cian) y simplifica la configuración Wayland al usar quickshell + dms-shell.

## 🛠️ Desarrollo

### Builds Manuales

Para compilar los binarios localmente:

```bash
# Compilar ambos binarios
make build

# Compilar solo orgmos
make build-orgmos

# Compilar solo orgmai (requiere pyinstaller)
make build-orgmai
```

Los binarios se generan en la carpeta `dist/`:
- `dist/orgmos` - Binario Go compilado
- `dist/orgmai` - Binario Python empaquetado con PyInstaller

**Requisitos para build-orgmai:**
```bash
pip install pyinstaller
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

Esto elimina la carpeta `dist/` y los artefactos de compilación.

## 📋 Requisitos del Sistema

- **Sistema**: Arch Linux (o basado en Arch)
- **WM**: i3-gaps o Niri
- **Fuentes**: JetBrainsMono Nerd Font
- **Terminal**: kitty o alacritty
- **Launcher**: rofi o wofi

## 🎯 Utilidades rápidas para i3

- `orgmos i3 wallpaper [random|restore|ruta]`
- `orgmos i3 lock`
- `orgmos i3 hotkey`
- `orgmos i3 powermenu`
- `orgmos i3 memory`

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
