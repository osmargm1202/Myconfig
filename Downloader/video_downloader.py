#!/usr/bin/env python3
"""
Descargador de videos universal con soporte para URLs TAR y HLS
Soporta Rumble y otros streams con HLS o TAR
"""

import sys
import subprocess
import tempfile
from pathlib import Path
from typing import List, Dict, Optional, Tuple
from urllib.parse import urlparse, parse_qs
from concurrent.futures import ThreadPoolExecutor, as_completed

try:
    from playwright.sync_api import sync_playwright
    from rich.progress import (
        Progress,
        SpinnerColumn,
        TextColumn,
        BarColumn,
        TaskProgressColumn,
    )
    import requests
except ImportError as e:
    print(
        "❌ Error: Faltan dependencias. Instala con: uv pip install playwright requests rich"
    )
    print(f"   Detalle: {e}")
    sys.exit(1)

# Importar funciones comunes
from common import (
    debug_log,
    is_tar_url,
    extract_tar_base_url,
    build_tar_url,
    download_with_range,
    parse_m3u8_manifest,
    combine_segments_with_ffmpeg,
    detect_browser,
    console,
)


def download_single_segment(
    args: Tuple[int, Dict[str, str], str, str, Dict[str, str], Path],
) -> Optional[Tuple[int, Path]]:
    """Descarga un segmento individual - función auxiliar para paralelización"""
    idx, seg_info, base_url, r_type, headers, temp_dir = args

    # Crear una sesión nueva para este thread para evitar problemas de concurrencia
    session = requests.Session()
    session.headers.update(headers)

    segment_url = seg_info["url"]
    segment_range = seg_info.get("range")

    # Si el segmento es relativo, construir URL completa
    if not segment_url.startswith("http"):
        r_file = segment_url
        # Usar el rango del manifest si está disponible, o intentar sin rango
        if segment_range:
            full_url = build_tar_url(base_url, r_file, r_type, segment_range)
        else:
            # Intentar descargar sin rango primero
            full_url = build_tar_url(base_url, r_file, r_type, "")
    else:
        full_url = segment_url

    # Intentar descargar el segmento
    content = None

    # Si tenemos un rango del manifest, usarlo
    if segment_range and "-" in segment_range:
        try:
            start, end = map(int, segment_range.split("-"))
            content = download_with_range(session, base_url, headers, start, end)
        except Exception:
            pass  # Intentar otros métodos

    # Si la URL tiene r_range, intentar usarlo
    if not content and "r_range=" in full_url:
        parsed = urlparse(full_url)
        query = parse_qs(parsed.query)
        r_range = query.get("r_range", [None])[0]

        if r_range and "-" in r_range:
            try:
                start, end = map(int, r_range.split("-"))
                content = download_with_range(session, base_url, headers, start, end)
            except Exception:
                pass  # Intentar descarga completa

    # Si aún no tenemos contenido, intentar descargar completo
    if not content:
        try:
            response = session.get(full_url, headers=headers, timeout=30)
            response.raise_for_status()
            content = response.content
        except Exception:
            return None

    if content:
        segment_file = temp_dir / f"segment_{idx:04d}.ts"
        segment_file.write_bytes(content)
        return (idx, segment_file)

    return None


def download_tar_segments(
    session: requests.Session,
    base_url: str,
    r_type: str,
    chunklist_url: str,
    headers: Dict[str, str],
    temp_dir: Path,
) -> List[Path]:
    """Descarga todos los segmentos TAR desde un chunklist.m3u8"""
    debug_log(f"Descargando chunklist desde: {chunklist_url[:80]}...")

    # Descargar el chunklist.m3u8
    # Si la URL tiene r_range, usarlo para descargar solo ese rango
    chunklist_content = None

    if is_tar_url(chunklist_url):
        tar_info = extract_tar_base_url(chunklist_url)
        if tar_info and tar_info.get("r_range"):
            # Descargar usando el rango especificado
            r_range = tar_info["r_range"]
            if "-" in r_range:
                try:
                    start, end = map(int, r_range.split("-"))
                    content_bytes = download_with_range(
                        session, base_url, headers, start, end
                    )
                    if content_bytes:
                        chunklist_content = content_bytes.decode(
                            "utf-8", errors="ignore"
                        )
                except Exception as e:
                    debug_log(f"Error descargando chunklist con rango: {e}", "warning")

    # Si no se pudo descargar con rango, intentar descarga completa
    if not chunklist_content:
        try:
            response = session.get(chunklist_url, headers=headers, timeout=30)
            response.raise_for_status()
            chunklist_content = response.text
            debug_log(f"Chunklist descargado: {len(chunklist_content)} bytes")
        except Exception as e:
            debug_log(f"Error descargando chunklist: {e}", "error")
            return []

    # Parsear el manifest
    segments_info = parse_m3u8_manifest(chunklist_content)
    debug_log(f"Encontrados {len(segments_info)} segmentos en el manifest")

    if not segments_info:
        debug_log("No se encontraron segmentos en el manifest", "error")
        return []

    # Preparar argumentos para descarga paralela
    # Usar 50 workers como sugiere el usuario
    max_workers = 50
    debug_log(
        f"Iniciando descarga paralela con {max_workers} workers simultáneos...",
        "success",
    )

    # Crear una sesión por worker para evitar problemas de concurrencia
    # Usaremos la misma sesión pero con locks si es necesario, o crear sesiones nuevas
    segment_files_dict = {}  # Usar dict para mantener orden por índice

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TaskProgressColumn(),
        console=console,
    ) as progress:
        task = progress.add_task(
            "[cyan]Descargando segmentos en paralelo...", total=len(segments_info)
        )

        # Preparar argumentos para cada segmento
        # No pasamos la sesión, cada worker creará la suya
        download_args = [
            (idx, seg_info, base_url, r_type, headers, temp_dir)
            for idx, seg_info in enumerate(segments_info)
        ]

        # Descargar segmentos en paralelo
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Enviar todas las tareas
            future_to_idx = {
                executor.submit(download_single_segment, args): args[0]
                for args in download_args
            }

            # Procesar resultados conforme se completan
            completed = 0
            for future in as_completed(future_to_idx):
                idx = future_to_idx[future]
                try:
                    result = future.result()
                    if result:
                        seg_idx, segment_file = result
                        segment_files_dict[seg_idx] = segment_file
                        completed += 1
                        if completed % 10 == 0:  # Log cada 10 segmentos para no saturar
                            debug_log(
                                f"Descargados {completed}/{len(segments_info)} segmentos..."
                            )
                except Exception as e:
                    debug_log(f"Error descargando segmento {idx}: {e}", "error")

                progress.update(task, advance=1)

    # Ordenar segmentos por índice y retornar lista
    segment_files = [segment_files_dict[i] for i in sorted(segment_files_dict.keys())]
    debug_log(
        f"Descarga completada: {len(segment_files)}/{len(segments_info)} segmentos descargados exitosamente",
        "success",
    )

    return segment_files


def descargar_video(url_video: str, destino: str) -> bool:
    """Descarga el video capturando en tiempo real con navegador"""

    # Detectar navegador disponible
    browser_name = detect_browser()
    if not browser_name:
        debug_log("No se encontró ningún navegador instalado", "error")
        debug_log("Instala Firefox, Chrome, Chromium o Edge", "info")
        return False

    debug_log(f"Usando navegador: {browser_name}", "success")
    debug_log("Abriendo navegador con sesión real...")

    with sync_playwright() as p:
        # Seleccionar el navegador detectado
        if browser_name == "firefox":
            browser = p.firefox.launch(headless=False)
        elif browser_name in ["chrome", "chromium"]:
            browser = p.chromium.launch(
                headless=False,
                args=[
                    "--disable-blink-features=AutomationControlled",
                    "--disable-web-security",
                ],
            )
        elif browser_name == "microsoft-edge":
            browser = p.chromium.launch(
                headless=False,
                channel="msedge",
                args=[
                    "--disable-blink-features=AutomationControlled",
                    "--disable-web-security",
                ],
            )
        else:
            browser = p.chromium.launch(
                headless=False,
                args=[
                    "--disable-blink-features=AutomationControlled",
                    "--disable-web-security",
                ],
            )

        context = browser.new_context(
            user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1920, "height": 1080},
        )

        page = context.new_page()

        # Almacenar todas las URLs y headers capturados
        video_requests = []

        def capturar_request(request):
            url = request.url
            if any(ext in url for ext in [".ts", ".m3u8", ".mp4", ".m4s", ".tar"]):
                video_requests.append({"url": url, "headers": request.headers})
                debug_log(f"Capturado: {url[:80]}...")

        page.on("request", capturar_request)

        debug_log(f"Navegando a: {url_video[:60]}...")
        try:
            page.goto(url_video, wait_until="load", timeout=60000)
        except Exception as e:
            error_msg = str(e)
            if "Download is starting" in error_msg:
                debug_log(
                    "El navegador detectó inicio de descarga, continuando captura...",
                    "warning",
                )
                # Esperar un poco para que se capturen más requests
                import time

                time.sleep(5)
            else:
                debug_log(f"Error navegando: {e}", "warning")
                # Continuar de todas formas para intentar capturar requests

        # Esperar que cargue el video
        debug_log("Esperando carga del video...")
        import time

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

        # Buscar URLs TAR primero
        tar_requests = [r for r in video_requests if is_tar_url(r["url"])]
        chunklist_requests = [r for r in video_requests if "chunklist.m3u8" in r["url"]]
        m3u8_requests = [
            r
            for r in video_requests
            if ".m3u8" in r["url"] and "chunklist" not in r["url"]
        ]

        # Determinar estrategia de descarga
        if tar_requests and chunklist_requests:
            debug_log("Detectado formato TAR con chunklist", "success")

            # Usar el primer chunklist encontrado
            chunklist_req = chunklist_requests[0]
            chunklist_url = chunklist_req["url"]
            headers = chunklist_req["headers"]

            # Extraer información de la URL TAR base
            tar_info = extract_tar_base_url(chunklist_url)
            if not tar_info:
                # Intentar con cualquier URL TAR
                tar_info = extract_tar_base_url(tar_requests[0]["url"])

            if tar_info:
                base_url = tar_info["base_url"]
                r_type = tar_info.get("r_type", "application/vnd.apple.mpegurl")

                # Crear directorio temporal para segmentos
                with tempfile.TemporaryDirectory() as temp_dir:
                    temp_path = Path(temp_dir)

                    # Crear sesión requests con headers
                    session = requests.Session()
                    session.headers.update(
                        {
                            "User-Agent": headers.get(
                                "user-agent",
                                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
                            ),
                            "Referer": headers.get("referer", url_video),
                        }
                    )

                    # Descargar segmentos
                    segment_files = download_tar_segments(
                        session, base_url, r_type, chunklist_url, headers, temp_path
                    )

                    if segment_files:
                        # Combinar segmentos
                        success = combine_segments_with_ffmpeg(
                            segment_files, destino, headers
                        )
                        return success
                    else:
                        debug_log("No se pudieron descargar segmentos", "error")
                        return False
            else:
                debug_log("No se pudo extraer información de URL TAR", "error")
                return False

        elif m3u8_requests:
            # Descarga HLS estándar
            debug_log("Usando manifest HLS estándar", "success")
            m3u8_req = m3u8_requests[0]
            target_url = m3u8_req["url"]
            headers = m3u8_req["headers"]

            debug_log(f"Descargando: {target_url[:80]}...")

            header_args = []
            for key, value in headers.items():
                if key.lower() in ["user-agent", "referer", "cookie", "origin"]:
                    header_args.extend(["-headers", f"{key}: {value}"])

            cmd = [
                "ffmpeg",
                *header_args,
                "-i",
                target_url,
                "-c",
                "copy",
                "-bsf:a",
                "aac_adtstoasc",
                destino,
                "-y",
                "-v",
                "warning",
                "-stats",
            ]

            try:
                result = subprocess.run(cmd)
                return result.returncode == 0
            except Exception as e:
                debug_log(f"Error ejecutando FFmpeg: {e}", "error")
                return False

        else:
            # Intentar con la última URL capturada
            debug_log("Usando última URL capturada", "warning")
            target_url = video_requests[-1]["url"]
            headers = video_requests[-1]["headers"]

            debug_log(f"Descargando: {target_url[:80]}...")

            header_args = []
            for key, value in headers.items():
                if key.lower() in ["user-agent", "referer", "cookie", "origin"]:
                    header_args.extend(["-headers", f"{key}: {value}"])

            cmd = [
                "ffmpeg",
                *header_args,
                "-i",
                target_url,
                "-c",
                "copy",
                "-bsf:a",
                "aac_adtstoasc",
                destino,
                "-y",
                "-v",
                "warning",
                "-stats",
            ]

            try:
                result = subprocess.run(cmd)
                return result.returncode == 0
            except Exception as e:
                debug_log(f"Error ejecutando FFmpeg: {e}", "error")
                return False


if __name__ == "__main__":
    if len(sys.argv) < 3:
        console.print("[red]Uso:[/red] python video_downloader.py <url_video> <destino>")
        sys.exit(1)

    url_video = sys.argv[1]
    destino = sys.argv[2]

    success = descargar_video(url_video, destino)

    if success:
        console.print(f"\n[green]✅ Video descargado:[/green] {destino}")
    else:
        console.print("\n[red]❌ Error en la descarga[/red]")
        sys.exit(1)
