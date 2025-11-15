#!/usr/bin/env python3
"""
Descargador de streams usando navegador para capturar requests
Abre el navegador, reproduce el video y captura las URLs de video
"""

import sys
import subprocess
import time
from pathlib import Path
from typing import List, Dict

try:
    from playwright.sync_api import sync_playwright
    from rich.console import Console
    import requests
except ImportError:
    print("❌ Error: Faltan dependencias. Instala con: uv pip install playwright requests rich")
    sys.exit(1)

from common import debug_log, console, detect_browser, parse_m3u8_manifest


def descargar_stream(url: str, destino: str) -> bool:
    """Descarga un stream abriendo navegador y capturando requests"""
    
    # Detectar navegador disponible
    browser_name = detect_browser()
    if not browser_name:
        debug_log("No se encontró ningún navegador instalado", "error")
        debug_log("Instala Firefox, Chrome, Chromium o Edge", "info")
        return False
    
    debug_log(f"Usando navegador: {browser_name}", "success")
    debug_log("Abriendo navegador para capturar stream...")
    
    with sync_playwright() as p:
        # Seleccionar el navegador detectado
        if browser_name == "firefox":
            browser = p.firefox.launch(headless=False)
        elif browser_name in ["chrome", "chromium"]:
            browser = p.chromium.launch(headless=False)
        elif browser_name == "microsoft-edge":
            browser = p.chromium.launch(
                headless=False,
                channel="msedge"
            )
        else:
            browser = p.chromium.launch(headless=False)
        
        context = browser.new_context(
            user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1920, "height": 1080}
        )
        
        page = context.new_page()
        
        # Almacenar todas las URLs y headers capturados
        video_requests = []
        
        def capturar_request(request):
            url_req = request.url
            if any(ext in url_req for ext in [".ts", ".m3u8", ".mp4", ".m4s", ".tar"]):
                video_requests.append({
                    "url": url_req,
                    "headers": request.headers
                })
                debug_log(f"Capturado: {url_req[:80]}...")
        
        page.on("request", capturar_request)
        
        debug_log(f"Navegando a: {url[:60]}...")
        try:
            page.goto(url, wait_until="load", timeout=60000)
        except Exception as e:
            error_msg = str(e)
            if "Download is starting" in error_msg:
                debug_log(
                    "El navegador detectó inicio de descarga, continuando captura...",
                    "warning",
                )
                time.sleep(5)
            else:
                debug_log(f"Error navegando: {e}", "warning")
        
        # Esperar que cargue el video
        debug_log("Esperando carga del video...")
        time.sleep(10)
        
        # Intentar reproducir si hay un botón de play
        try:
            page.click('button[aria-label*="play"], .play-button, video', timeout=3000)
            debug_log("Reproduciendo video...")
            time.sleep(5)
        except Exception:
            debug_log(
                "No se encontró botón de play (puede no ser necesario)", "warning"
            )
        
        # Esperar más para capturar más requests
        time.sleep(10)
        
        browser.close()
        
        if not video_requests:
            debug_log("No se capturaron requests de video", "error")
            return False
        
        debug_log(f"Total de requests capturados: {len(video_requests)}")
        
        # Buscar m3u8 primero (HLS)
        m3u8_requests = [r for r in video_requests if ".m3u8" in r["url"]]
        mp4_requests = [r for r in video_requests if ".mp4" in r["url"]]
        
        # Determinar estrategia de descarga
        if m3u8_requests:
            debug_log("Detectado stream HLS", "success")
            m3u8_req = m3u8_requests[0]
            target_url = m3u8_req["url"]
            headers = m3u8_req["headers"]
            
            debug_log(f"Descargando stream HLS: {target_url[:80]}...")
            
            # Usar FFmpeg para descargar HLS
            header_args = []
            for key, value in headers.items():
                if key.lower() in ["user-agent", "referer", "cookie", "origin"]:
                    header_args.extend(["-headers", f"{key}: {value}"])
            
            cmd = [
                "ffmpeg",
                *header_args,
                "-i", target_url,
                "-c", "copy",
                "-bsf:a", "aac_adtstoasc",
                destino,
                "-y",
                "-v", "warning",
                "-stats",
            ]
            
            try:
                result = subprocess.run(cmd)
                return result.returncode == 0
            except Exception as e:
                debug_log(f"Error ejecutando FFmpeg: {e}", "error")
                return False
        
        elif mp4_requests:
            debug_log("Detectado video MP4 directo", "success")
            mp4_req = mp4_requests[0]
            target_url = mp4_req["url"]
            headers = mp4_req["headers"]
            
            debug_log(f"Descargando video: {target_url[:80]}...")
            
            # Descargar usando requests
            session = requests.Session()
            session.headers.update(headers)
            
            try:
                response = session.get(target_url, stream=True, timeout=30)
                response.raise_for_status()
                
                destino_path = Path(destino)
                destino_path.parent.mkdir(parents=True, exist_ok=True)
                
                total_size = int(response.headers.get('content-length', 0))
                downloaded = 0
                
                with open(destino, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                            downloaded += len(chunk)
                            if total_size > 0:
                                percent = (downloaded / total_size) * 100
                                if downloaded % (1024 * 1024) == 0:  # Log cada MB
                                    debug_log(f"Descargado: {downloaded / (1024*1024):.1f} MB / {total_size / (1024*1024):.1f} MB ({percent:.1f}%)")
                
                debug_log("Video descargado exitosamente", "success")
                return True
            except Exception as e:
                debug_log(f"Error descargando video: {e}", "error")
                return False
        
        else:
            debug_log("No se pudo detectar el tipo de stream", "error")
            debug_log("URLs capturadas:", "info")
            for req in video_requests[:5]:  # Mostrar primeras 5
                debug_log(f"  - {req['url'][:80]}...", "info")
            return False


if __name__ == "__main__":
    if len(sys.argv) < 3:
        console.print("[red]Uso:[/red] python stream_downloader.py <url> <destino>")
        sys.exit(1)
    
    url = sys.argv[1]
    destino = sys.argv[2]
    
    success = descargar_stream(url, destino)
    
    if success:
        console.print(f"\n[green]✅ Video descargado:[/green] {destino}")
    else:
        console.print("\n[red]❌ Error en la descarga[/red]")
        sys.exit(1)

