#!/bin/bash
# ORGMOS Video Downloader - Menú principal

# Verificar dependencias
for cmd in gum python ffmpeg; do
  if ! command -v $cmd &>/dev/null; then
    echo "❌ Error: $cmd no está instalado"
    exit 1
  fi
done

# Configurar colores de gum
export GUM_CHOOSE_SELECTED_FOREGROUND="#87CEEB"  # Azul cielo para selección
export GUM_CHOOSE_CURSOR_FOREGROUND="#87CEEB"    # Azul cielo para cursor
export GUM_INPUT_CURSOR_FOREGROUND="#87CEEB"     # Azul cielo para input
export GUM_INPUT_PROMPT_FOREGROUND="#87CEEB"     # Azul cielo para prompt

# Obtener ruta del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Título con color azul
gum style \
  --foreground "#0000FF" --border-foreground "#0000FF" --border double \
  --align center --width 50 --margin "1 2" --padding "1 4" \
  '📥 ORGMOS Video Downloader' 'Selecciona el tipo de descarga'

# Menú principal
TIPO_DESCARGA=$(gum choose \
  --header="Selecciona el tipo de descarga:" \
  --cursor="> " \
  "YouTube Downloader" \
  "Filemon Downloader (HLS)" \
  "Stream Downloader (con navegador)" \
  "Video Downloader Universal (TAR/Rumble)")

if [[ -z "$TIPO_DESCARGA" ]]; then
  gum style --foreground 196 "❌ Operación cancelada"
  exit 0
fi

# Solicitar URL
echo ""
gum style --foreground "#0000FF" "🔗 Ingresa la URL del video:"
URL_VIDEO=$(gum input --placeholder "https://ejemplo.com/video.mp4")

if [[ -z "$URL_VIDEO" ]]; then
  gum style --foreground 196 "❌ URL vacía"
  exit 1
fi

# Seleccionar carpeta de destino
CARPETAS=(
  "$HOME/Downloads"
  "/mnt/Jellyfin/Peliculas"
  "/mnt/Jellyfin/Series"
  "Otra carpeta..."
)

echo ""
gum style --foreground "#0000FF" "📁 Carpeta de destino:"
CARPETA_SELECCIONADA=$(gum choose "${CARPETAS[@]}")

if [[ "$CARPETA_SELECCIONADA" == "Otra carpeta..." ]]; then
  CARPETA_DESTINO=$(gum input --placeholder "/ruta/completa")
else
  CARPETA_DESTINO="$CARPETA_SELECCIONADA"
fi

[[ ! -d "$CARPETA_DESTINO" ]] && mkdir -p "$CARPETA_DESTINO"

# Solicitar nombre de archivo
NOMBRE_ARCHIVO=$(gum input --placeholder "video.mp4" --value "video.mp4")
DESTINO="$CARPETA_DESTINO/$NOMBRE_ARCHIVO"

# Mostrar resumen
gum style --border normal --margin "1" --padding "1 2" --border-foreground "#0000FF" \
  "Tipo: $TIPO_DESCARGA" \
  "URL: $URL_VIDEO" \
  "Destino: $DESTINO"

gum confirm "¿Continuar?" || exit 0

# Determinar qué script ejecutar según la selección
case "$TIPO_DESCARGA" in
  "YouTube Downloader")
    PYTHON_SCRIPT="$SCRIPT_DIR/youtube_downloader.py"
    ;;
  "Filemon Downloader (HLS)")
    PYTHON_SCRIPT="$SCRIPT_DIR/filemon_downloader.py"
    ;;
  "Stream Downloader (con navegador)")
    PYTHON_SCRIPT="$SCRIPT_DIR/stream_downloader.py"
    ;;
  "Video Downloader Universal (TAR/Rumble)")
    PYTHON_SCRIPT="$SCRIPT_DIR/video_downloader.py"
    ;;
  *)
    gum style --foreground 196 "❌ Tipo de descarga no válido"
    exit 1
    ;;
esac

# Verificar que el script existe
if [[ ! -f "$PYTHON_SCRIPT" ]]; then
  gum style --foreground 196 "❌ Error: No se encuentra el script: $PYTHON_SCRIPT"
  exit 1
fi

# Ejecutar script Python
echo ""
python "$PYTHON_SCRIPT" "$URL_VIDEO" "$DESTINO"

RESULT=$?

if [[ $RESULT -eq 0 ]] && [[ -f "$DESTINO" ]]; then
  TAMAÑO=$(du -h "$DESTINO" | awk '{print $1}')
  gum style \
    --foreground "#0000FF" --border-foreground "#0000FF" --border double \
    --align center --width 50 --margin "1 2" --padding "1 2" \
    "✅ Descarga completada" \
    "" \
    "📁 $DESTINO" \
    "📊 Tamaño: $TAMAÑO"
else
  gum style --foreground 196 --border normal --border-foreground 196 --padding "1 2" \
    "❌ Error en la descarga"
  exit 1
fi
