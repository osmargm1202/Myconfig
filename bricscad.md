# Solución BricsCAD - Error libxml2.so.2
## Problema
BricsCAD (64-bit) incluía su propia libxml2.so.2 de 32 bits, causando conflicto de arquitectura.
Requisitos del Sistema
bashsudo pacman -S libxml2
Solución Aplicada
bashcd ~/Apps/bc

# Respaldar la biblioteca original de 32 bits
mv libxml2.so.2 libxml2.so.2.bak

# Crear symlink a la biblioteca de 64 bits del sistema
ln -s /usr/lib/libxml2.so.16 libxml2.so.2
Ejecución
bashcd ~/Apps/bc
bash -c 'export LD_LIBRARY_PATH=/home/osmar/Apps/bc:$LD_LIBRARY_PATH && ./bricscad.sh'
Nota
Si BricsCAD incluye otras bibliotecas de 32 bits que causen problemas similares, aplicar el mismo procedimiento: respaldar la .so original y crear symlink a la versión de 64 bits del sistema en /usr/lib/.
