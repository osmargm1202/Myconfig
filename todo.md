# utilziar bat sin numeracion de linea en orgmai last

# quita de orgmai.py todos los debus message para que sea compilado finalmente.

# agrega que el make file copie los binarios a la carpeta que toca no que lo haga install.sh,, esto por si quiero hacer los binarios localmente, y not ener que ejecutar el isntall.sh que esta dedicado a usar con curl.


# hazme una funcion con nuevo proyecto nuevop la carpeta fija sera ~/Nextcloud/Proyectos/[input].


Pedir nombre de la carpeta madre usando gum
NOMBRE_MADRE=$(gum input --placeholder "Nombre de la carpeta madre")

# Crear carpeta madre
mkdir -p "$NOMBRE_MADRE"

# Crear carpetas hijas dentro de la carpeta madre
mkdir -p "$NOMBRE_MADRE"/Comunicacion \
         "$NOMBRE_MADRE"/Diseño \
         "$NOMBRE_MADRE"/Estudios \
         "$NOMBRE_MADRE"/Calculos \
         "$NOMBRE_MADRE"/Levantamientos \
         "$NOMBRE_MADRE"/Entregas \
         "$NOMBRE_MADRE"/Recibido \
         "$NOMBRE_MADRE"/Oferta

echo "Carpeta '$NOMBRE_MADRE' creada con sus subcarpetas."