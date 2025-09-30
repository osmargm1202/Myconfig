# Changelog - Myconfig

## Objetivo General del Proyecto
Configuración completa y automatizada para i3wm en Arch Linux con temas Tokyo Night, herramientas de gestión de energía, aplicaciones web nativas, y scripts de productividad.

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
