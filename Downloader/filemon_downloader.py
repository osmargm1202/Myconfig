#!/usr/bin/env python3
"""
Descargador de videos HLS para Filemon y otros servicios con streams HLS
"""

import sys
import subprocess
from pathlib import Path
from typing import Dict

try:
    from rich.console import Console
    import requests
except ImportError:
    print("❌ Error: Faltan dependencias. Instala con: uv pip install requests rich")
    sys.exit(1)

from common import debug_log, console, parse_m3u8_manifest


def descargar_hls(url: str, destino: str, headers: Dict[str, str] = None) -> bool:
    """Descarga un stream HLS (.m3u8) usando FFmpeg"""
    
    if not url.endswith(".m3u8") and ".m3u8" not in url:
        debug_log("La URL no parece ser un stream HLS (.m3u8)", "error")
        return False
    
    debug_log(f"Descargando stream HLS: {url[:60]}...")
    
    # Asegurar que el directorio de destino existe
    destino_path = Path(destino)
    if not destino_path.parent.exists():
        destino_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Construir comando FFmpeg
    cmd = [
        "ffmpeg",
        "-i", url,
        "-c", "copy",
        "-bsf:a", "aac_adtstoasc",
        str(destino),
        "-y",
        "-v", "warning",
        "-stats",
    ]
    
    # Agregar headers si se proporcionan
    if headers:
        header_args = []
        for key, value in headers.items():
            if key.lower() in ["user-agent", "referer", "cookie", "origin"]:
                header_args.extend(["-headers", f"{key}: {value}"])
        if header_args:
            # Insertar headers después de -i
            cmd = cmd[:2] + header_args + cmd[2:]
    
    try:
        debug_log("Ejecutando FFmpeg para descargar stream HLS...")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            debug_log("Stream HLS descargado exitosamente", "success")
            return True
        else:
            debug_log(f"Error en FFmpeg: {result.stderr}", "error")
            return False
    except Exception as e:
        debug_log(f"Error ejecutando FFmpeg: {e}", "error")
        return False


if __name__ == "__main__":
    if len(sys.argv) < 3:
        console.print("[red]Uso:[/red] python filemon_downloader.py <url_m3u8> <destino>")
        sys.exit(1)
    
    url = sys.argv[1]
    destino = sys.argv[2]
    
    success = descargar_hls(url, destino)
    
    if success:
        console.print(f"\n[green]✅ Video descargado:[/green] {destino}")
    else:
        console.print("\n[red]❌ Error en la descarga[/red]")
        sys.exit(1)

