# ORGMOS - Sistema de Configuración Multi-Distro

Sistema de configuración completo para **Arch Linux**, **Debian** y **Ubuntu** con soporte para i3wm, Niri y tema Tokyo Night.

## 🚀 Instalación Rápida

```bash
curl -fsSL custom.or-gm.com/orgmos.sh | sh
```

Este comando:
- ✅ Clona/actualiza el repositorio en `~/Myconfig`
- ✅ Copia el binario `orgmos` a `~/.local/bin/`
- ✅ Crea entrada de escritorio

## 📦 Instalación Manual

```bash
git clone https://github.com/osmargm1202/Myconfig.git ~/Myconfig
cd ~/Myconfig
cp orgmos ~/.local/bin/
chmod +x ~/.local/bin/orgmos
```

## 🎯 Uso

### Menú Interactivo

```bash
orgmos menu
```

El menú principal permite seleccionar la distribución:
- **Arch Linux** - Soporte completo con AUR, i3, Niri, Flatpak
- **Debian** - Paquetes base, generales, extras y red
- **Ubuntu** - Paquetes base, generales, extras y red

## 📋 Comandos por Distribución

### Arch Linux

| Comando | Descripción |
|---------|-------------|
| `orgmos i3` | Instalar i3 Window Manager y componentes |
| `orgmos niri` | Instalar Niri Window Manager (Wayland) |
| `orgmos arch` | Herramientas de terminal (fish, kitty, starship, etc.) |
| `orgmos general` | Paquetes generales (editores, fuentes, temas) |
| `orgmos extras` | Paquetes extras (lazygit, tmux, ctop, etc.) |
| `orgmos network` | Herramientas de red y seguridad |
| `orgmos flatpak` | Aplicaciones Flatpak (Steam, Discord, etc.) |
| `orgmos paru` | Instalar Paru AUR Helper |

### Debian

| Comando | Descripción |
|---------|-------------|
| `orgmos debian base` | Paquetes base del sistema |
| `orgmos debian general` | Paquetes generales |
| `orgmos debian extras` | Paquetes extras |
| `orgmos debian network` | Herramientas de red |

### Ubuntu

| Comando | Descripción |
|---------|-------------|
| `orgmos ubuntu base` | Paquetes base del sistema |
| `orgmos ubuntu general` | Paquetes generales |
| `orgmos ubuntu extras` | Paquetes extras |
| `orgmos ubuntu network` | Herramientas de red |

### Comandos Compartidos (todas las distros)

| Comando | Descripción |
|---------|-------------|
| `orgmos config` | Copiar configuraciones a ~/.config |
| `orgmos assets` | Descargar wallpapers |
| `orgmos menu` | Menú interactivo principal |

### Utilidades i3 (solo Arch)

| Comando | Descripción |
|---------|-------------|
| `orgmos i3 wallpaper [random\|restore\|ruta]` | Cambiar wallpaper |
| `orgmos i3 lock` | Bloquear pantalla |
| `orgmos i3 hotkey` | Mostrar atajos de teclado |
| `orgmos i3 powermenu` | Menú de energía |
| `orgmos i3 memory` | Uso de memoria |
| `orgmos i3 reload` | Recargar i3 y polybar |

## 📁 Estructura del Proyecto

```
Myconfig/
├── cmd/orgmos/          # Código fuente Go
├── internal/            # Módulos internos
│   ├── ui/             # Estilos y UI
│   ├── packages/       # Gestión de paquetes
│   └── utils/          # Utilidades
├── configs/            # Archivos TOML de paquetes
│   ├── arch/           # Paquetes para Arch Linux
│   ├── debian/         # Paquetes para Debian
│   └── ubuntu/         # Paquetes para Ubuntu
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

- ✅ **Multi-distribución** - Arch Linux, Debian y Ubuntu
- ✅ **Interfaz moderna** con Huh y Lipgloss
- ✅ **Detección automática** de paquetes instalados
- ✅ **Soporte AUR** con Paru (Arch)
- ✅ **Gestión de Flatpak** (Arch)
- ✅ **Window Managers** - i3 y Niri (Arch)
- ✅ **Tema Tokyo Night** integrado

## 🎛️ Shell Wayland (DMS Shell)

Para Niri en Arch Linux:
- DMS Shell replica módulos de polybar optimizados para Wayland
- Paleta **Tokyo Night** con fondos translúcidos
- Integración con quickshell + dms-shell

## 🛠️ Desarrollo

```bash
# Compilar binario (requiere Go)
make build

# Ejecutar sin instalar
go run ./cmd/orgmos menu

# Limpiar
make clean
```

## 📋 Requisitos

### Arch Linux
- Paru (se instala automáticamente si falta)
- i3-gaps o Niri (opcional)

### Debian / Ubuntu
- apt (gestor de paquetes por defecto)

### Todos
- Git
- Terminal compatible (kitty recomendado)

## 📄 Licencia

Este proyecto es de uso personal. Siéntete libre de usarlo como base para tus propias configuraciones.

---

**URL de instalación:** `custom.or-gm.com/orgmos.sh`
