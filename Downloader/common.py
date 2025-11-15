#!/usr/bin/env python3
"""
Funciones comunes compartidas entre los diferentes descargadores
"""

import re
import urllib.parse
from pathlib import Path
from typing import List, Dict, Optional, Tuple
from urllib.parse import urlparse, parse_qs

try:
    from rich.console import Console
    from rich.progress import (
        Progress,
        SpinnerColumn,
        TextColumn,
        BarColumn,
        TaskProgressColumn,
    )
    import requests
except ImportError as e:
    print(f"❌ Error: Faltan dependencias. Instala con: uv pip install requests rich")
    print(f"   Detalle: {e}")
    import sys
    sys.exit(1)

console = Console()


def debug_log(message: str, level: str = "info"):
    """Log de debug con colores"""
    if level == "info":
        console.print(f"[blue]🔍[/blue] {message}")
    elif level == "success":
        console.print(f"[green]✓[/green] {message}")
    elif level == "warning":
        console.print(f"[yellow]⚠[/yellow] {message}")
    elif level == "error":
        console.print(f"[red]✗[/red] {message}")


def is_tar_url(url: str) -> bool:
    """Detecta si una URL es de tipo TAR con rangos"""
    return ".tar?" in url and "r_file=" in url and "r_range=" in url


def extract_tar_base_url(url: str) -> Optional[Dict[str, str]]:
    """Extrae la URL base y parámetros de una URL TAR"""
    try:
        parsed = urlparse(url)
        query = parse_qs(parsed.query)

        base_url = f"{parsed.scheme}://{parsed.netloc}{parsed.path}"
        r_file = query.get("r_file", [None])[0]
        r_type = query.get("r_type", [None])[0]
        r_range = query.get("r_range", [None])[0]

        if r_file and r_range:
            return {
                "base_url": base_url,
                "r_file": r_file,
                "r_type": r_type,
                "r_range": r_range,
            }
    except Exception as e:
        debug_log(f"Error extrayendo URL TAR: {e}", "error")
    return None


def build_tar_url(base_url: str, r_file: str, r_type: str, r_range: str) -> str:
    """Construye una URL TAR completa"""
    params = {"r_file": r_file, "r_type": r_type or "video/mp2t", "r_range": r_range}
    query_string = "&".join(
        [f"{k}={urllib.parse.quote(v)}" for k, v in params.items() if v]
    )
    return f"{base_url}?{query_string}"


def download_with_range(
    session: requests.Session, url: str, headers: Dict[str, str], start: int, end: int
) -> Optional[bytes]:
    """Descarga un rango específico de bytes de una URL"""
    range_header = f"bytes={start}-{end}"
    headers_with_range = {**headers, "Range": range_header}

    try:
        response = session.get(url, headers=headers_with_range, timeout=30)
        response.raise_for_status()

        if response.status_code == 206:  # Partial Content
            return response.content
        elif response.status_code == 200:
            # Si no soporta rangos, devuelve todo el contenido
            return response.content
        else:
            return None
    except Exception:
        return None


def parse_m3u8_manifest(content: str) -> List[Dict[str, str]]:
    """Parsea un manifest M3U8 y extrae información de segmentos"""
    segments = []
    lines = content.strip().split("\n")

    i = 0
    current_range = None
    while i < len(lines):
        line = lines[i].strip()

        # Buscar información de rango en #EXT-X-BYTERANGE
        if line.startswith("#EXT-X-BYTERANGE:"):
            range_match = re.search(r"#EXT-X-BYTERANGE:(\d+)@(\d+)", line)
            if range_match:
                size = int(range_match.group(1))
                offset = int(range_match.group(2))
                current_range = f"{offset}-{offset + size - 1}"
            else:
                # Formato alternativo: solo tamaño
                size_match = re.search(r"#EXT-X-BYTERANGE:(\d+)", line)
                if size_match:
                    size = int(size_match.group(1))
                    # Necesitaremos calcular el offset basado en segmentos anteriores
                    current_range = None  # Se calculará después

        # Buscar líneas #EXTINF que indican segmentos
        if line.startswith("#EXTINF:"):
            if i + 1 < len(lines):
                segment_url = lines[i + 1].strip()
                if segment_url and not segment_url.startswith("#"):
                    # Extraer duración si está disponible
                    duration_match = re.search(r"#EXTINF:([\d.]+)", line)
                    duration = duration_match.group(1) if duration_match else None

                    segments.append(
                        {
                            "url": segment_url,
                            "duration": duration,
                            "range": current_range,
                        }
                    )
                    current_range = None  # Reset para el siguiente segmento
                i += 2
            else:
                i += 1
        else:
            i += 1

    return segments


def combine_segments_with_ffmpeg(
    segment_files: List[Path], output_path: str, headers: Dict[str, str]
) -> bool:
    """Combina segmentos usando FFmpeg"""
    if not segment_files:
        debug_log("No hay segmentos para combinar", "error")
        return False

    debug_log(f"Combinando {len(segment_files)} segmentos...")

    # Crear archivo de lista para FFmpeg concat
    concat_file = segment_files[0].parent / "concat_list.txt"
    with open(concat_file, "w") as f:
        for seg_file in segment_files:
            f.write(f"file '{seg_file.absolute()}'\n")

    # Usar FFmpeg para combinar
    import subprocess
    cmd = [
        "ffmpeg",
        "-f",
        "concat",
        "-safe",
        "0",
        "-i",
        str(concat_file),
        "-c",
        "copy",
        "-bsf:a",
        "aac_adtstoasc",
        output_path,
        "-y",
        "-v",
        "warning",
        "-stats",
    ]

    try:
        debug_log("Ejecutando FFmpeg para combinar segmentos...")
        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode == 0:
            debug_log("Segmentos combinados exitosamente", "success")
            return True
        else:
            debug_log(f"Error en FFmpeg: {result.stderr}", "error")
            return False
    except Exception as e:
        debug_log(f"Error ejecutando FFmpeg: {e}", "error")
        return False
    finally:
        # Limpiar archivo de lista
        if concat_file.exists():
            concat_file.unlink()


def detect_browser() -> Optional[str]:
    """Detecta qué navegador está disponible en el sistema"""
    import shutil
    
    browsers = ["firefox", "chrome", "chromium", "microsoft-edge", "brave"]
    for browser in browsers:
        if shutil.which(browser):
            return browser
    return None

