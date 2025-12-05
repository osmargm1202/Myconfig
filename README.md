# ORGMOS - Sistema de Configuración para Arch Linux

Sistema de configuración completo para i3wm, Niri, rofi y aplicaciones con tema Tokyo Night.

## 🚀 Instalación Rápida (Una línea)

```bash
curl -fsSL https://raw.githubusercontent.com/osmargm1202/Myconfig/master/install.sh | bash
```

Este comando:
- ✅ Clona/actualiza el repositorio en `~/Myconfig`
- ✅ Copia el binario `orgmos` a `~/.local/bin/`
- ✅ Crea entrada de escritorio

## 📦 Instalación Manual

### 1. Clonar repositorio

```bash
git clone https://github.com/osmargm1202/Myconfig.git ~/Myconfig
cd ~/Myconfig
```

### 2. Copiar binario

```bash
cp orgmos ~/.local/bin/
chmod +x ~/.local/bin/orgmos
```

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
| `orgmos arch` | Herramientas de terminal para Arch (pkg_arch.toml) |
| `orgmos general` | Paquetes generales (pkg_general.toml) |
| `orgmos extras` | Paquetes extras (pkg_extras.toml) |
| `orgmos network` | Herramientas de red y seguridad (pkg_networks.toml) |
| `orgmos flatpak` | Instalador de aplicaciones Flatpak (pkg_flatpak.toml) |
| `orgmos paru` | Instalar Paru AUR Helper |
| `orgmos config` | Copiar configuraciones a ~/.config |
| `orgmos assets` | Descargar wallpapers |
| `orgmos menu` | Menú interactivo principal |

### Ejemplos

```bash
# Instalar i3 completo
orgmos i3

# Instalar Niri
orgmos niri

# Instalar herramientas de terminal Arch
orgmos arch

# Instalar paquetes generales
orgmos general

# Instalar herramientas de red
orgmos network

# Instalar Paru AUR Helper
orgmos paru

# Copiar todas las configuraciones
orgmos config

# Descargar wallpapers
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
│   └── utils/          # Utilidades
├── configs/            # Archivos TOML de paquetes
│   ├── pkg_arch.toml
│   ├── pkg_general.toml
│   ├── pkg_extras.toml
│   ├── pkg_networks.toml
│   ├── pkg_i3.toml
│   ├── pkg_niri.toml
│   └── pkg_flatpak.toml
├── configs_to_copy/    # Configuraciones para ~/.config
└── orgmos              # Binario precompilado
```

## 🔧 Actualización

```bash
cd ~/Myconfig
git pull origin master
cp orgmos ~/.local/bin/
```

## 🎨 Características

- ✅ **Interfaz moderna** con Huh y Lipgloss
- ✅ **Colores personalizados** (azul, verde, amarillo, rojo)
- ✅ **Instalación directa** - instala todos los paquetes del archivo TOML
- ✅ **Detección automática** de paquetes instalados
- ✅ **Soporte AUR** con Paru
- ✅ **Gestión de Flatpak**
- ✅ **Sin selección manual** - flujo simplificado

## 🎛️ Shell Wayland (Polybar ➜ DMS Shell)

- DMS Shell replica los módulos críticos de la barra (workspaces, título de ventana, fecha/hora, filesystem, audio, batería, métricas y toggles de hotkeys/powermenu) pero optimizados para Wayland.
- Los atajos `orgmos i3 …` alimentan los módulos personalizados para mantener el flujo de trabajo en i3 y Niri.
- El tema aplica la misma paleta **Tokyo Night** (fondos translúcidos + acentos lila/cian) y simplifica la configuración Wayland al usar quickshell + dms-shell.

## 🛠️ Desarrollo

### Compilar localmente

```bash
# Compilar binario
make build

# Ejecutar sin instalar
make run
# o
go run ./cmd/orgmos menu

# Limpiar
make clean
```

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

O se instalará automáticamente cuando sea necesario al ejecutar otros comandos de instalación.

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
