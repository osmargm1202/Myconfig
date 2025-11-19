#!/usr/bin/env python3
"""
Script para analizar wallpapers y renombrarlos con nombres descriptivos en español.
Analiza colores dominantes, características visuales y genera nombres apropiados.
"""

import os
import sys
from pathlib import Path
from PIL import Image
import numpy as np
from collections import Counter
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn
from rich.table import Table
import re

console = Console()

# Directorio de wallpapers
WALLPAPERS_DIR = Path.home() / "Myconfig" / "Wallpapers"

# Extensiones de imagen soportadas
IMAGE_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.bmp', '.webp'}

# Diccionario de colores en español
COLOR_NAMES = {
    'red': 'rojo', 'orange': 'naranja', 'yellow': 'amarillo',
    'green': 'verde', 'blue': 'azul', 'purple': 'morado',
    'pink': 'rosa', 'brown': 'marrón', 'black': 'negro',
    'white': 'blanco', 'gray': 'gris', 'grey': 'gris',
    'cyan': 'cian', 'magenta': 'magenta', 'turquoise': 'turquesa',
    'violet': 'violeta', 'indigo': 'índigo', 'lime': 'lima',
    'gold': 'dorado', 'silver': 'plateado', 'beige': 'beige',
    'coral': 'coral', 'salmon': 'salmón', 'navy': 'azul marino',
    'teal': 'verde azulado', 'olive': 'oliva', 'maroon': 'granate'
}

# Palabras descriptivas comunes
DESCRIPTIVE_WORDS = {
    'abstract': 'abstracto',
    'landscape': 'paisaje',
    'nature': 'naturaleza',
    'city': 'ciudad',
    'night': 'noche',
    'day': 'día',
    'sunset': 'atardecer',
    'sunrise': 'amanecer',
    'foggy': 'neblina',
    'mist': 'niebla',
    'mountains': 'montañas',
    'ocean': 'océano',
    'sky': 'cielo',
    'clouds': 'nubes',
    'dark': 'oscuro',
    'light': 'claro',
    'bright': 'brillante',
    'gradient': 'degradado',
    'minimal': 'minimalista',
    'geometric': 'geométrico',
    'pattern': 'patrón',
    'texture': 'textura',
    'smooth': 'suave',
    'rough': 'áspero'
}


def rgb_to_color_name(r, g, b):
    """Convierte un color RGB a un nombre aproximado en español."""
    # Convertir a int si son numpy types
    r, g, b = int(r), int(g), int(b)
    
    # Colores de referencia simples
    colors = {
        'negro': (0, 0, 0),
        'blanco': (255, 255, 255),
        'rojo': (255, 0, 0),
        'verde': (0, 255, 0),
        'azul': (0, 0, 255),
        'amarillo': (255, 255, 0),
        'cian': (0, 255, 255),
        'magenta': (255, 0, 255),
        'naranja': (255, 165, 0),
        'rosa': (255, 192, 203),
        'morado': (128, 0, 128),
        'marrón': (165, 42, 42),
        'gris': (128, 128, 128),
        'turquesa': (64, 224, 208),
        'dorado': (255, 215, 0),
        'plateado': (192, 192, 192),
        'verde azulado': (0, 128, 128),
        'azul marino': (0, 0, 128),
        'verde lima': (50, 205, 50),
    }
    
    min_dist = float('inf')
    closest_color = 'gris'
    
    for color_name, (cr, cg, cb) in colors.items():
        dist = ((r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2) ** 0.5
        if dist < min_dist:
            min_dist = dist
            closest_color = color_name
    
    return closest_color


def get_dominant_colors(image, k=3):
    """Extrae los colores dominantes de una imagen usando muestreo y agrupación mejorada."""
    console.print(f"[DEBUG] Analizando colores dominantes (k={k})", style="dim")
    
    # Redimensionar para análisis más rápido
    img = image.copy()
    img.thumbnail((200, 200), Image.Resampling.LANCZOS)
    
    # Convertir a array numpy
    pixels = np.array(img)
    
    # Si la imagen tiene canal alpha, eliminarlo
    if pixels.shape[2] == 4:
        pixels = pixels[:, :, :3]
    
    # Aplanar la imagen
    pixels = pixels.reshape(-1, 3)
    
    # Filtrar píxeles muy oscuros o muy claros (menos informativos)
    # Calcular brillo de cada píxel
    brightness = np.mean(pixels, axis=1)
    # Mantener píxeles con brillo entre 20 y 235 (evitar negro puro y blanco puro)
    mask = (brightness >= 20) & (brightness <= 235)
    filtered_pixels = pixels[mask]
    
    # Si después del filtro no hay suficientes píxeles, usar todos
    if len(filtered_pixels) < 100:
        filtered_pixels = pixels
    
    # Muestrear para análisis más rápido
    if len(filtered_pixels) > 15000:
        indices = np.random.choice(len(filtered_pixels), 15000, replace=False)
        sampled_pixels = filtered_pixels[indices]
    else:
        sampled_pixels = filtered_pixels
    
    # Agrupar colores similares usando un método mejorado
    # Usar agrupación más fina pero agrupar colores muy similares
    colors = []
    for pixel in sampled_pixels:
        r, g, b = pixel
        # Agrupar en rangos más pequeños pero agrupar colores muy similares
        # Usar división por 16 para más granularidad
        r_bin = (r // 16) * 16
        g_bin = (g // 16) * 16
        b_bin = (b // 16) * 16
        colors.append((r_bin, g_bin, b_bin))
    
    # Contar colores más frecuentes
    color_counts = Counter(colors)
    dominant = color_counts.most_common(k * 2)  # Obtener más candidatos
    
    # Filtrar colores muy similares entre sí
    unique_colors = []
    for color, count in dominant:
        r, g, b = color
        # Verificar si es muy similar a algún color ya seleccionado
        is_similar = False
        for ur, ug, ub in unique_colors:
            dist = ((r - ur) ** 2 + (g - ug) ** 2 + (b - ub) ** 2) ** 0.5
            if dist < 40:  # Si la distancia es menor a 40, son muy similares
                is_similar = True
                break
        
        if not is_similar:
            unique_colors.append((r, g, b))
            if len(unique_colors) >= k:
                break
    
    # Si no tenemos suficientes colores únicos, agregar los más frecuentes restantes
    if len(unique_colors) < k:
        for color, count in dominant:
            if color not in unique_colors:
                unique_colors.append(color)
                if len(unique_colors) >= k:
                    break
    
    console.print(f"[DEBUG] Colores dominantes encontrados: {len(unique_colors)}", style="dim")
    
    return unique_colors[:k]


def analyze_image(image_path):
    """Analiza una imagen y extrae características visuales."""
    console.print(f"[DEBUG] Analizando imagen: {image_path.name}", style="dim")
    
    try:
        img = Image.open(image_path)
        console.print(f"[DEBUG] Imagen cargada: {img.size[0]}x{img.size[1]}, modo: {img.mode}", style="dim")
    except Exception as e:
        console.print(f"[ERROR] No se pudo abrir {image_path}: {e}", style="red")
        return None
    
    # Convertir a RGB si es necesario
    if img.mode != 'RGB':
        img = img.convert('RGB')
        console.print(f"[DEBUG] Imagen convertida a RGB", style="dim")
    
    # Obtener colores dominantes
    dominant_colors = get_dominant_colors(img)
    console.print(f"[DEBUG] Colores dominantes RGB: {dominant_colors}", style="dim")
    
    # Convertir a nombres de colores
    color_names = [rgb_to_color_name(r, g, b) for r, g, b in dominant_colors]
    console.print(f"[DEBUG] Nombres de colores: {color_names}", style="dim")
    
    # Calcular brillo promedio
    pixels = np.array(img)
    if len(pixels.shape) == 3:
        brightness = np.mean(pixels) / 255.0
    else:
        brightness = 0.5
    
    console.print(f"[DEBUG] Brillo promedio: {brightness:.2f}", style="dim")
    
    # Calcular contraste (desviación estándar)
    if len(pixels.shape) == 3:
        contrast = np.std(pixels) / 255.0
    else:
        contrast = 0.5
    
    console.print(f"[DEBUG] Contraste: {contrast:.2f}", style="dim")
    
    # Determinar si es oscuro o claro
    is_dark = brightness < 0.4
    is_bright = brightness > 0.7
    has_high_contrast = contrast > 0.3
    
    console.print(f"[DEBUG] Características: oscuro={is_dark}, brillante={is_bright}, alto_contraste={has_high_contrast}", style="dim")
    
    return {
        'dominant_colors': color_names,
        'brightness': brightness,
        'contrast': contrast,
        'is_dark': is_dark,
        'is_bright': is_bright,
        'has_high_contrast': has_high_contrast,
        'size': img.size
    }


def generate_descriptive_name(image_path, analysis):
    """Genera un nombre descriptivo en español basado en el análisis."""
    console.print(f"[DEBUG] Generando nombre descriptivo para: {image_path.name}", style="dim")
    
    if analysis is None:
        return None
    
    parts = []
    
    # Intentar extraer información del nombre original primero (tiene prioridad)
    original_name = image_path.stem.lower()
    console.print(f"[DEBUG] Nombre original: {original_name}", style="dim")
    
    # Buscar palabras clave en el nombre original
    keywords_found = []
    for eng_word, esp_word in DESCRIPTIVE_WORDS.items():
        if eng_word in original_name:
            keywords_found.append(esp_word)
            console.print(f"[DEBUG] Palabra clave encontrada: {eng_word} -> {esp_word}", style="dim")
    
    # Agregar palabras clave encontradas primero (tienen más información)
    if keywords_found:
        parts.extend(keywords_found[:2])  # Máximo 2 palabras clave
    
    # Agregar colores dominantes (máximo 2, pero evitar si ya hay palabras clave descriptivas)
    colors = analysis['dominant_colors'][:2]
    if colors:
        # Filtrar colores muy oscuros si ya tenemos palabras clave
        filtered_colors = []
        for color in colors:
            # Si el color es negro y ya tenemos "oscuro" o es muy oscuro, omitirlo
            if color == 'negro' and ('oscuro' in parts or analysis['is_dark']):
                continue
            filtered_colors.append(color)
        
        if filtered_colors:
            # Si hay un solo color dominante, usarlo
            if len(filtered_colors) == 1:
                parts.append(filtered_colors[0])
            elif len(filtered_colors) >= 2 and filtered_colors[0] != filtered_colors[1]:
                # Combinar colores diferentes
                parts.append(f"{filtered_colors[0]}-{filtered_colors[1]}")
            else:
                parts.append(filtered_colors[0])
    
    console.print(f"[DEBUG] Parte de colores: {parts}", style="dim")
    
    # Agregar características de brillo solo si no es redundante
    has_black_color = any('negro' in part for part in parts)
    if analysis['is_dark'] and 'oscuro' not in parts and not has_black_color:
        parts.append('oscuro')
    elif analysis['is_bright'] and 'brillante' not in parts:
        parts.append('brillante')
    
    # Agregar características de contraste solo si es significativo
    if analysis['has_high_contrast'] and 'contraste' not in parts:
        parts.append('contraste')
    
    # Si no hay suficientes partes, agregar descriptor genérico
    if len(parts) < 2:
        if analysis['is_dark']:
            if 'abstracto' not in parts:
                parts.append('abstracto')
        else:
            if 'paisaje' not in parts:
                parts.append('paisaje')
    
    # Limitar a 4 partes máximo
    parts = parts[:4]
    
    # Eliminar duplicados manteniendo el orden
    seen = set()
    unique_parts = []
    for part in parts:
        # Normalizar para comparación (sin guiones internos)
        normalized = part.replace('-', '')
        if normalized not in seen:
            seen.add(normalized)
            unique_parts.append(part)
    parts = unique_parts
    
    # Unir partes con guiones
    name = '-'.join(parts)
    
    # Limpiar nombre (solo letras, números y guiones)
    name = re.sub(r'[^a-z0-9áéíóúñü-]', '', name.lower())
    name = re.sub(r'-+', '-', name)  # Reemplazar múltiples guiones
    name = name.strip('-')  # Eliminar guiones al inicio/final
    
    console.print(f"[DEBUG] Nombre generado: {name}", style="dim")
    
    return name


def sanitize_filename(name):
    """Sanitiza un nombre de archivo para que sea válido."""
    # Reemplazar caracteres no válidos
    name = re.sub(r'[<>:"/\\|?*]', '', name)
    # Limitar longitud
    if len(name) > 100:
        name = name[:100]
    return name


def rename_wallpapers(wallpapers_dir, dry_run=False):
    """Analiza y renombra todos los wallpapers."""
    if not wallpapers_dir.exists():
        console.print(f"[ERROR] Directorio no encontrado: {wallpapers_dir}", style="red")
        return
    
    # Obtener todos los archivos de imagen
    image_files = []
    for ext in IMAGE_EXTENSIONS:
        image_files.extend(wallpapers_dir.glob(f"*{ext}"))
        image_files.extend(wallpapers_dir.glob(f"*{ext.upper()}"))
    
    if not image_files:
        console.print("[ERROR] No se encontraron archivos de imagen", style="red")
        return
    
    console.print(f"[INFO] Encontrados {len(image_files)} archivos de imagen", style="green")
    
    # Crear tabla para mostrar resultados
    table = Table(title="Análisis de Wallpapers")
    table.add_column("Archivo Original", style="cyan")
    table.add_column("Nuevo Nombre", style="green")
    table.add_column("Colores", style="yellow")
    table.add_column("Estado", style="magenta")
    
    renamed_count = 0
    skipped_count = 0
    
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        console=console
    ) as progress:
        task = progress.add_task("[cyan]Analizando wallpapers...", total=len(image_files))
        
        for image_path in image_files:
            progress.update(task, description=f"[cyan]Analizando {image_path.name}...")
            
            # Analizar imagen
            analysis = analyze_image(image_path)
            
            if analysis is None:
                table.add_row(image_path.name, "ERROR", "", "[red]Error al analizar")
                skipped_count += 1
                progress.advance(task)
                continue
            
            # Generar nuevo nombre
            new_name_base = generate_descriptive_name(image_path, analysis)
            
            if not new_name_base:
                table.add_row(image_path.name, "ERROR", "", "[red]No se pudo generar nombre")
                skipped_count += 1
                progress.advance(task)
                continue
            
            # Sanitizar nombre
            new_name_base = sanitize_filename(new_name_base)
            
            # Mantener extensión original
            extension = image_path.suffix
            new_name = f"{new_name_base}{extension}"
            new_path = wallpapers_dir / new_name
            
            # Verificar si el nuevo nombre ya existe
            if new_path.exists() and new_path != image_path:
                # Agregar número al final
                counter = 1
                while new_path.exists():
                    new_name = f"{new_name_base}-{counter}{extension}"
                    new_path = image_path.parent / new_name
                    counter += 1
            
            # Mostrar en tabla
            colors_str = ", ".join(analysis['dominant_colors'][:2])
            if new_path == image_path:
                table.add_row(image_path.name, new_name, colors_str, "[yellow]Sin cambios")
                skipped_count += 1
            else:
                if dry_run:
                    table.add_row(image_path.name, new_name, colors_str, "[blue]DRY RUN")
                else:
                    try:
                        image_path.rename(new_path)
                        table.add_row(image_path.name, new_name, colors_str, "[green]Renombrado")
                        renamed_count += 1
                    except Exception as e:
                        table.add_row(image_path.name, new_name, colors_str, f"[red]Error: {e}")
                        skipped_count += 1
            
            progress.advance(task)
    
    # Mostrar tabla
    console.print("\n")
    console.print(table)
    console.print(f"\n[INFO] Resumen: {renamed_count} renombrados, {skipped_count} omitidos", style="green")


def main():
    """Función principal."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Analiza y renombra wallpapers con nombres descriptivos en español"
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Muestra los cambios sin renombrar archivos'
    )
    parser.add_argument(
        '--dir',
        type=str,
        default=str(WALLPAPERS_DIR),
        help=f'Directorio de wallpapers (default: {WALLPAPERS_DIR})'
    )
    
    args = parser.parse_args()
    
    wallpapers_dir = Path(args.dir)
    
    if args.dry_run:
        console.print("[INFO] Modo DRY RUN activado - no se realizarán cambios", style="yellow")
    
    rename_wallpapers(wallpapers_dir, dry_run=args.dry_run)


if __name__ == "__main__":
    main()

