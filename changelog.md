# Changelog - Myconfig

## Objetivo General del Proyecto
Configuración completa y automatizada para i3wm en Arch Linux con temas Tokyo Night, herramientas de gestión de energía, aplicaciones web nativas, y scripts de productividad.

---

## [2025-10-07] - Integración de Instalador de Flatpak

### Añadido
- **Script de instalación de Flatpak** (`Apps/install_flatpak.sh`):
  - Verifica e instala Flatpak si no está disponible
  - Agrega repositorio Flathub automáticamente
  - Lee lista de aplicaciones desde `Apps/pkg_flatpak.lst`
  - **Instala aplicaciones nuevas** desde Flathub
  - **Actualiza aplicaciones ya instaladas** automáticamente
  - Proporciona resumen detallado de instalación
  - Contador de aplicaciones: procesadas, instaladas, actualizadas y errores
  - Colores informativos en la salida (verde, amarillo, rojo)
  - Manejo individual de errores sin interrumpir el proceso

- **Lista de aplicaciones Flatpak** (`Apps/pkg_flatpak.lst`):
  - **Multimedia**: Clapper, VideoDownloader, OBS Studio
  - **Utilidades**: Flatseal, Warehouse, Impression, MissionCenter
  - **Comunicación**: Webcord (Discord client)
  - **Diseño**: Blender, GIMP, Inkscape, Krita, Upscaler
  - **Visualizadores**: Eye of GNOME
  - **Virtualización**: GNOME Boxes
  - Formato: ID de aplicación por línea, comentarios con #

- **Integración en menú principal** (`setup.sh`):
  - Nueva opción 5: "Install Flatpak Apps - Aplicaciones desde Flathub"
  - Función `install_flatpak()` para ejecución interactiva
  - Función `install_flatpak_silent()` para instalación automática
  - Integrado en instalación completa (paso 3/6)
  - Menú actualizado de 10 a 11 opciones totales

### Modificado
- **Script install_flatpak.sh**:
  - Corregido path del archivo de lista para detectar automáticamente `pkg_flatpak.lst`
  - Agregado `SCRIPT_DIR` para resolver paths relativos correctamente
  - Lista predeterminada ahora es `$SCRIPT_DIR/pkg_flatpak.lst`
  
- **Flujo de instalación automática** (`setup.sh`):
  - Paso 1: AUR Helper
  - Paso 2: Paquetes del sistema
  - **Paso 3: Aplicaciones Flatpak** ← NUEVO
  - Paso 4: Configuraciones del sistema
  - Paso 5: WebApp Creator
  - Paso 6: SDDM (opcional)

### Características del Instalador
- ✅ Verificación de Flatpak instalado
- ✅ Configuración automática de repositorio Flathub
- ✅ **Instalación de apps nuevas** desde Flathub
- ✅ **Actualización de apps ya instaladas** (mantiene todo actualizado)
- ✅ Instalación no interactiva con flag `-y`
- ✅ Manejo individual de errores (no interrumpe el proceso)
- ✅ Resumen final con estadísticas detalladas
- ✅ Soporte para comentarios en lista
- ✅ Colores informativos en terminal

### Uso

**Individual:**
```bash
# Desde el directorio Apps/
./install_flatpak.sh

# Con lista personalizada
./install_flatpak.sh mi_lista.lst
```

**Desde menú:**
```bash
./setup.sh
# Seleccionar opción 5: Install Flatpak Apps
```

**Instalación completa:**
```bash
./setup.sh
# Seleccionar opción 1: Instalación Completa Automática
# Flatpak apps se instalarán automáticamente en el paso 3
```

### Formato de pkg_flatpak.lst
```txt
# === CATEGORÍA ===
com.example.App1
org.example.App2

# Comentarios permitidos
# Líneas vacías ignoradas
```

### Propósito
Centralizar la gestión de aplicaciones Flatpak con instalación y actualización automática, mantener una lista reproducible de apps siempre actualizadas, y facilitar la configuración y mantenimiento del sistema con un solo comando.

### Correcciones Aplicadas
- **Fix inicial**: Removido `set -e` que causaba cierre prematuro del script
- **Mejora**: Cambiado de "omitir" a "actualizar" aplicaciones existentes
- **Estabilidad**: Manejo robusto de errores individuales por aplicación

---

## [2025-09-30] - Fix: Gum no funcionaba con instalación remota (curl)

### Problema Identificado
Cuando se ejecutaba el instalador con `curl -fsSL | bash`:
- Los scripts de instalación detectaban que Gum estaba instalado
- PERO fallaban en usarlo debido a verificación incorrecta de TTY
- Resultado: menús fallback simples en lugar de la interfaz bonita de Gum

### Causa Raíz
Scripts verificaban `[[ -t 0 && -c /dev/tty ]]` antes de usar Gum:
- **`-t 0`** verifica si stdin (fd 0) es una terminal
- Con `curl | bash`, stdin viene del pipe, NO de terminal
- Aunque `/dev/tty` existía y Gum estaba instalado, la condición fallaba

### Archivos Corregidos
- ✅ `Apps/install_plymouth.sh`:
  - Función `ask_confirmation()` (línea 31)
  - Función `show_theme_menu()` (línea 87)
  - Wait prompt final (línea 416)
  
- ✅ `Apps/install_sddm.sh`:
  - Función `ask_confirmation()` (línea 68)
  - Wait prompt final (línea 413)
  
- ✅ `Apps/install_wallpapers.sh`:
  - Función `ask_confirmation()` (línea 34)
  
- ✅ `Apps/install_system76.sh`:
  - Wait prompt final (línea 124)

### Cambios Realizados
**ANTES:**
```bash
if [[ "$HAS_GUM" == true ]] && [[ -t 0 && -c /dev/tty ]]; then
  gum confirm "$message"
```

**DESPUÉS:**
```bash
if [[ "$HAS_GUM" == true ]] && [[ -c /dev/tty ]]; then
  gum confirm "$message" < /dev/tty
```

### Mejoras Implementadas
1. ❌ Eliminada verificación de `stdin` (`-t 0`)
2. ✅ Mantenida verificación de `/dev/tty` existe
3. ✅ Agregado redirect explícito `< /dev/tty` a Gum
4. ✅ Scripts ahora leen correctamente desde terminal aunque stdin venga de pipe

### Resultado
Ahora **SIEMPRE** se usa Gum (si está instalado), sin importar cómo se ejecute:
- ✅ Local: `./setup.sh` → Gum funciona
- ✅ Remoto: `curl -fsSL ... | bash` → Gum funciona  
- ✅ Fallback: Si Gum no está → menú tradicional

### Testing
```bash
# Método 1: Local (ya funcionaba)
git clone https://github.com/osmargm1202/Myconfig.git
cd Myconfig
./setup.sh

# Método 2: Remoto (ahora también funciona con Gum!)
bash <(curl -fsSL https://raw.githubusercontent.com/osmargm1202/Myconfig/master/install.sh)
```

---

## [2025-09-30] - Mejoras en Flujo de Instalación

### Corregido
- **Scripts de instalación que cerraban prematuramente**:
  - `Apps/install_plymouth.sh`: Agregada pausa al final del script
  - `Apps/install_sddm.sh`: Agregada pausa al final del script  
  - `Apps/install_system76.sh`: Mejorada pausa al final del script
  
- **Modo automático eliminado**:
  - `Apps/install_plymouth.sh`: Removida ejecución automática sin confirmación
  - Ahora siempre requiere interacción del usuario para seleccionar tema
  - Eliminadas verificaciones de TTY que permitían omitir confirmaciones

### Añadido
- **Permisos de ejecución automáticos** (`install.sh`):
  - Al clonar o actualizar el repositorio, se otorgan permisos `+x` a:
    - Todos los scripts `.sh` en `Apps/`
    - Todos los scripts `.sh` en `Launcher/`
  - Feedback visual del proceso de permisos
  - Manejo de errores si no existen archivos

### Problema Resuelto
1. Los scripts de instalación volvían inmediatamente al menú principal sin dar tiempo al usuario para leer los resultados
2. Plymouth ejecutaba en modo automático sin permitir selección manual del tema
3. Los scripts descargados no tenían permisos de ejecución, causando errores

### Solución Implementada
- Agregado `read -p "Presiona Enter para volver al menú principal..."` al final de cada script
- Removidas todas las verificaciones de modo no-interactivo en plymouth
- Agregado `chmod +x` automático en `install.sh` después de clonar/actualizar
- Comportamiento consistente y siempre interactivo

### Impacto
Ahora los usuarios pueden:
- Ver los mensajes de éxito/error antes de volver al menú
- Leer las notas importantes y comandos útiles
- Tener control total sobre la selección de temas
- Ejecutar scripts sin necesidad de dar permisos manualmente

---

## [2025-09-30] - Integración de System76 Power Management

### Añadido
- **Script de instalación** (`Apps/install_system76.sh`):
  - Instala `system76-power` (daemon de gestión de energía)
  - Instala `system76-power-gui-x11` (interfaz gráfica)
  - Habilita e inicia el servicio systemd automáticamente
  - Verifica dependencias (yay/paru)
  - Proporciona feedback detallado durante la instalación

- **Integración con i3** (`i3/config`):
  - Agregado autostart del daemon `system76-power` al iniciar i3
  - Línea: `exec --no-startup-id system76-power daemon`

- **Módulo de batería en Polybar** (`polybar/config.ini`):
  - Nuevo módulo `[module/battery]` con:
    - Soporte para estados: charging, discharging, full, low
    - Iconos animados para carga
    - Iconos de capacidad de batería (5 niveles)
    - Colores Tokyo Night integrados
    - **Click izquierdo**: abre `system76-power-gui-x11`
  - Agregado a la barra: `modules-right = ... battery ...`

- **Opción en Setup** (`setup.sh`):
  - Nueva opción 8: "Install System76 Power - Power management tools"
  - Función `install_system76()` para ejecutar el instalador
  - Menú actualizado de 9 a 10 opciones

- **Documentación** (`README.md`):
  - Sección de System76 Power con ejemplos de uso
  - Comandos para cambiar perfiles de energía
  - Características principales del sistema

### Propósito
Mejorar la gestión de energía en laptops, especialmente para usuarios que necesitan optimizar el uso de batería o rendimiento según el contexto (batería, balanceado, rendimiento máximo).

### Detalles Técnicos
- **Batería detectada**: BAT0 (configurable en polybar)
- **Adaptador**: AC
- **Polling interval**: 5 segundos
- **Umbral low battery**: 15%
- **Umbral full**: 98%

### Comandos Útiles
```bash
# Instalar
./Apps/install_system76.sh

# Ver perfil actual
system76-power profile

# Cambiar perfil
system76-power profile battery
system76-power profile balanced
system76-power profile performance

# Abrir GUI (o click en batería de polybar)
system76-power-gui-x11
```

---

## Historial Previo

### Funcionalidades existentes antes de este cambio:
- i3wm configurado con tema Tokyo Night
- Polybar con múltiples módulos (CPU, memoria, temperatura, red, etc.)
- WebApp Creator para crear aplicaciones web nativas
- GameMode para optimización de juegos
- Sistema de wallpapers aleatorios
- SDDM theme (Corners)
- Plymouth boot splash
- Instalador automático con menú interactivo (Gum)
- Scripts de instalación modulares en `Apps/`
