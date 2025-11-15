#!/usr/bin/env python3
"""
Descargador de videos de YouTube usando yt-dlp
"""

import sys
import subprocess
from pathlib import Path

try:
    from rich.console import Console
except ImportError:
    print("❌ Error: Faltan dependencias. Instala con: uv pip install rich")
    sys.exit(1)

from common import debug_log, console


def descargar_youtube(url: str, destino: str, calidad: str = "best") -> bool:
    """Descarga un video de YouTube usando yt-dlp"""
    
    # Verificar si yt-dlp está instalado
    if not subprocess.which("yt-dlp"):
        debug_log("yt-dlp no está instalado", "error")
        debug_log("Instala con: pip install yt-dlp o pacman -S yt-dlp", "info")
        return False
    
    debug_log(f"Descargando video de YouTube: {url[:60]}...")
    
    # Asegurar que el directorio de destino existe
    destino_path = Path(destino)
    if not destino_path.parent.exists():
        destino_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Construir comando yt-dlp
    cmd = [
        "yt-dlp",
        "-f", calidad,  # Formato/calidad
        "-o", str(destino),  # Archivo de salida
        "--no-playlist",  # Solo el video, no la playlist
        url,
    ]
    
    try:
        debug_log("Ejecutando yt-dlp...")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            debug_log("Video descargado exitosamente", "success")
            return True
        else:
            debug_log(f"Error en yt-dlp: {result.stderr}", "error")
            return False
    except Exception as e:
        debug_log(f"Error ejecutando yt-dlp: {e}", "error")
        return False


if __name__ == "__main__":
    if len(sys.argv) < 3:
        console.print("[red]Uso:[/red] python youtube_downloader.py <url> <destino> [calidad]")
        console.print("[yellow]Calidad:[/yellow] best, worst, bestvideo+bestaudio, etc.")
        sys.exit(1)
    
    url = sys.argv[1]
    destino = sys.argv[2]
    calidad = sys.argv[3] if len(sys.argv) > 3 else "best"
    
    success = descargar_youtube(url, destino, calidad)
    
    if success:
        console.print(f"\n[green]✅ Video descargado:[/green] {destino}")
    else:
        console.print("\n[red]❌ Error en la descarga[/red]")
        sys.exit(1)

