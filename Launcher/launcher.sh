#!/bin/bash

DIR="$HOME/.local/share/applications"

# Crear lista con "NombreDeApp|Archivo.desktop"
apps=$(grep -h "^Name=" "$DIR"/*.desktop | sed 's/^Name=//' | while read -r name; do
  file=$(grep -l "Name=$name" "$DIR"/*.desktop | head -n1)
  echo "$name|$(basename "$file")"
done)

# Mostrar solo los nombres
opcion=$(echo "$apps" | cut -d'|' -f1 | rofi -dmenu -p "Apps")

# Buscar el archivo asociado y ejecutarlo
if [ -n "$opcion" ]; then
  file=$(echo "$apps" | grep "^$opcion|" | cut -d'|' -f2)
  gtk-launch "${file%.desktop}"
fi
