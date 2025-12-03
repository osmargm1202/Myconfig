#!/usr/bin/env python3
"""
orgmweb - Creador y gestor de WebApps

- Usa gum para la interacción en CLI
- Usa bat/less/cat para mostrar información
- Usa wget para descargar iconos
- Guarda el registro de WebApps en JSON en ~/.local/share/applications/webapps.json
- Crea .desktop en ~/.local/share/applications
- Guarda iconos en ~/.local/share/icons
"""

import json
import os
import subprocess
import sys
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import List, Optional
from urllib.parse import urlparse

try:
    from rich.console import Console
except ImportError:  # fallback muy simple si rich no está
    Console = None  # type: ignore


# Paths base
HOME = Path.home()
APPLICATIONS_DIR = HOME / ".local" / "share" / "applications"
ICONS_DIR = HOME / ".local" / "share" / "icons"
WEBAPPS_JSON = APPLICATIONS_DIR / "webapps.json"


# Debug console (regla del usuario: siempre logs de debug)
console = Console() if Console is not None else None


def debug(msg: str) -> None:
    """Debug log siempre activo durante desarrollo."""
    if console:
        console.print(f"[bold cyan][orgmweb][debug][/bold cyan] {msg}")
    else:
        print(f"[orgmweb][debug] {msg}")


def check_tool(tool: str) -> bool:
    """Verifica si una herramienta está disponible en PATH."""
    result = subprocess.run(["which", tool], capture_output=True, check=False)
    available = result.returncode == 0
    debug(f"check_tool({tool}) -> {available}")
    return available


def gum_style(*args: str) -> None:
    """Imprime usando gum style si está disponible, si no, print normal."""
    if check_tool("gum"):
        subprocess.run(["gum", "style", *args], check=False)
    else:
        # join para que sea legible también sin gum
        print(" ".join(args))


def error_exit(message: str, code: int = 1) -> None:
    """Muestra error y sale del programa."""
    debug(f"error_exit: {message}")
    if check_tool("gum"):
        subprocess.run(
            ["gum", "style", "--foreground", "204", "--bold", message], check=False
        )
    else:
        print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(code)


def gum_input(prompt: str = ">") -> Optional[str]:
    """Obtiene input del usuario usando gum."""
    if not check_tool("gum"):
        error_exit("gum no está instalado. Instala con: paru -S gum")

    debug(f"gum_input prompt={prompt!r}")
    result = subprocess.run(
        ["gum", "input", "--prompt", prompt],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    value = (result.stdout or "").strip()
    debug(f"gum_input result={value!r}")
    return value or None


def gum_choose(options: List[str], prompt: str = "Selecciona:") -> Optional[str]:
    """Muestra opciones usando gum choose."""
    if not options:
        debug("gum_choose sin opciones")
        return None

    if not check_tool("gum"):
        error_exit("gum no está instalado. Instala con: paru -S gum")

    debug(f"gum_choose prompt={prompt!r} options={options}")
    proc = subprocess.Popen(
        ["gum", "choose", "--header", prompt, *options],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    stdout, _ = proc.communicate()
    if proc.returncode != 0:
        debug(f"gum_choose cancelado (code={proc.returncode})")
        return None
    value = (stdout or "").strip()
    debug(f"gum_choose seleccionado={value!r}")
    return value or None


def gum_confirm(message: str) -> bool:
    """Confirmación con gum confirm."""
    if not check_tool("gum"):
        error_exit("gum no está instalado. Instala con: paru -S gum")

    debug(f"gum_confirm message={message!r}")
    result = subprocess.run(["gum", "confirm", message], check=False)
    confirmed = result.returncode == 0
    debug(f"gum_confirm -> {confirmed}")
    return confirmed


def show_markdown(text: str) -> None:
    """Muestra texto (markdown) usando bat/less/cat."""
    debug("show_markdown llamado")
    if check_tool("bat"):
        proc = subprocess.Popen(
            ["bat", "--paging=always", "--language=markdown", "--style=plain"],
            stdin=subprocess.PIPE,
            text=True,
        )
        proc.communicate(text)
    elif check_tool("less"):
        proc = subprocess.Popen(
            ["less", "-R"],
            stdin=subprocess.PIPE,
            text=True,
        )
        proc.communicate(text)
    else:
        print(text)


def ensure_env() -> None:
    """Asegura que los directorios y el JSON existan."""
    debug("ensure_env")
    APPLICATIONS_DIR.mkdir(parents=True, exist_ok=True)
    ICONS_DIR.mkdir(parents=True, exist_ok=True)
    if not WEBAPPS_JSON.exists():
        debug(f"Creando JSON vacío en {WEBAPPS_JSON}")
        WEBAPPS_JSON.write_text("[]", encoding="utf-8")


def sanitize_filename(name: str) -> str:
    """Normaliza nombres para usarlos como nombre de archivo."""
    cleaned = "".join(c for c in name if c.isalnum() or c in (" ", "-", "_")).strip()
    cleaned = cleaned.replace(" ", "-")
    cleaned = cleaned.replace("/", "-")
    cleaned = cleaned.lower()
    debug(f"sanitize_filename({name!r}) -> {cleaned!r}")
    return cleaned or "webapp"


@dataclass
class WebApp:
    name: str
    url: str
    description: str
    icon: str  # nombre de archivo relativo en ICONS_DIR
    created: str


def load_webapps() -> List[WebApp]:
    """Carga la lista de WebApps desde JSON."""
    ensure_env()
    try:
        data = json.loads(WEBAPPS_JSON.read_text(encoding="utf-8"))
        apps = [WebApp(**item) for item in data]
        debug(f"load_webapps -> {len(apps)} apps")
        return apps
    except FileNotFoundError:
        debug("load_webapps -> JSON no encontrado, devolviendo []")
        return []
    except Exception as exc:
        debug(f"load_webapps error: {exc}")
        return []


def save_webapps(apps: List[WebApp]) -> None:
    """Guarda la lista de WebApps en JSON."""
    ensure_env()
    data = [asdict(a) for a in apps]
    WEBAPPS_JSON.write_text(
        json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    debug(f"save_webapps -> {len(apps)} apps guardadas")


def ensure_browser() -> str:
    """Detecta navegador compatible (chromium/chromium-browser/google-chrome)."""
    debug("ensure_browser")
    candidates = [
        "chromium",
        "chromium-browser",
        "google-chrome",
        "google-chrome-stable",
    ]
    for c in candidates:
        if check_tool(c):
            debug(f"Browser detectado: {c}")
            return c
    error_exit(
        "No se encontró un navegador compatible (chromium/chrome). "
        "Instala por ejemplo: sudo pacman -S chromium"
    )
    return ""  # solo para type checkers


def run_wget(url: str, target: Path) -> bool:
    """Descarga un archivo con wget -q -O."""
    if not check_tool("wget"):
        error_exit("wget no está instalado. Instala con: sudo pacman -S wget")

    debug(f"run_wget url={url!r} target={str(target)!r}")
    cmd = ["wget", "-q", "-O", str(target), url]
    res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ok = res.returncode == 0 and target.exists() and target.stat().st_size > 0
    debug(f"run_wget -> {ok}")
    if not ok and target.exists():
        try:
            target.unlink()
        except OSError:
            pass
    return ok


def download_icon_auto(app_url: str, app_name: str) -> Optional[Path]:
    """Intenta descargar el icono automáticamente desde favicon."""
    debug(f"download_icon_auto url={app_url!r} name={app_name!r}")
    ensure_env()
    parsed = urlparse(app_url)
    if not parsed.scheme or not parsed.netloc:
        debug("download_icon_auto: URL inválida para favicon")
        return None

    base = f"{parsed.scheme}://{parsed.netloc}"
    target = ICONS_DIR / f"{sanitize_filename(app_name)}.png"

    # 1) favicon.ico directo
    favicon_url = f"{base}/favicon.ico"
    if run_wget(favicon_url, target):
        debug("download_icon_auto: favicon.ico descargado")
        return target

    # 2) Google Favicon API
    google_url = f"https://www.google.com/s2/favicons?domain={parsed.netloc}&sz=128"
    if run_wget(google_url, target):
        debug("download_icon_auto: descargado desde Google Favicon API")
        return target

    debug("download_icon_auto: falló descarga automática")
    return None


def download_icon_from_url(icon_url: str, app_name: str) -> Optional[Path]:
    """Descarga icono desde una URL proporcionada por el usuario."""
    debug(f"download_icon_from_url url={icon_url!r} name={app_name!r}")
    ensure_env()
    target = ICONS_DIR / f"{sanitize_filename(app_name)}.png"
    if run_wget(icon_url, target):
        return target
    return None


def create_desktop_file(app: WebApp, browser: str) -> Path:
    """Crea el archivo .desktop para la WebApp."""
    ensure_env()
    filename = f"{sanitize_filename(app.name)}.desktop"
    desktop_path = APPLICATIONS_DIR / filename
    icon_name = app.icon  # nombre de archivo relativo

    debug(f"create_desktop_file name={app.name!r} path={str(desktop_path)!r}")

    content = f"""[Desktop Entry]
Version=1.0
Type=Application
Name={app.name}
Comment={app.description}
Exec={browser} --app=\"{app.url}\" --new-window --class=\"{app.name}\"
Icon={icon_name}
Categories=Network;WebBrowser;
NoDisplay=false
StartupWMClass={app.name}
StartupNotify=true
Terminal=false
"""
    desktop_path.write_text(content, encoding="utf-8")
    os.chmod(desktop_path, 0o755)
    debug("create_desktop_file: .desktop creado")
    return desktop_path


def append_or_replace(apps: List[WebApp], app: WebApp) -> List[WebApp]:
    """Añade o reemplaza WebApp por nombre (case-insensitive)."""
    debug(f"append_or_replace: {app.name!r}")
    lowered = app.name.lower()
    for idx, existing in enumerate(apps):
        if existing.name.lower() == lowered:
            apps[idx] = app
            return apps
    apps.append(app)
    return apps


def create_webapp_flow() -> None:
    """Flow para crear una nueva WebApp."""
    debug("create_webapp_flow inicio")
    ensure_env()
    browser = ensure_browser()

    name = gum_input("Nombre de la WebApp> ")
    if not name:
        debug("create_webapp_flow cancelado: sin nombre")
        return

    url = gum_input("URL (https:// se agregará si falta)> ")
    if not url:
        debug("create_webapp_flow cancelado: sin URL")
        return

    url = url.strip()
    if not url.startswith("http://") and not url.startswith("https://"):
        url = "https://" + url
    debug(f"create_webapp_flow url normalizada={url!r}")

    description = gum_input("Descripción (opcional)> ") or f"{name} WebApp"

    # Intentar descarga automática de icono
    icon_path = download_icon_auto(url, name)
    if icon_path is None:
        gum_style(
            "--foreground", "214", "No se pudo descargar el icono automáticamente."
        )
        # Pedir URL de icono al usuario
        while True:
            icon_url = gum_input("URL del icono (.png) o vacío para cancelar> ")
            if not icon_url:
                debug("create_webapp_flow cancelado: sin URL de icono")
                return
            icon_path = download_icon_from_url(icon_url, name)
            if icon_path is not None:
                break
            gum_style(
                "--foreground",
                "204",
                "No se pudo descargar el icono. Intenta con otra URL.",
            )

    icon_name = icon_path.name if icon_path is not None else ""

    app = WebApp(
        name=name,
        url=url,
        description=description,
        icon=icon_name,
        created=datetime.utcnow().isoformat(),
    )

    create_desktop_file(app, browser)

    apps = load_webapps()
    apps = append_or_replace(apps, app)
    save_webapps(apps)

    gum_style("--foreground", "42", f"WebApp '{name}' creada correctamente.")
    debug("create_webapp_flow fin OK")


def list_webapps_flow() -> None:
    """Lista webapps y permite lanzar una."""
    debug("list_webapps_flow inicio")
    apps = load_webapps()
    if not apps:
        gum_style("--foreground", "214", "No hay WebApps registradas.")
        return

    options = [f"{a.name} ({a.url})" for a in apps]
    selected = gum_choose(options, "Selecciona una WebApp para lanzar")
    if not selected:
        debug("list_webapps_flow cancelado por usuario")
        return

    name = selected.split(" (", 1)[0]
    debug(f"list_webapps_flow seleccionado={name!r}")
    app = next((a for a in apps if a.name == name), None)
    if not app:
        gum_style("--foreground", "204", "No se encontró la WebApp seleccionada.")
        return

    launch_webapp(app)


def launch_webapp(app: WebApp) -> None:
    """Lanza una WebApp en modo app."""
    debug(f"launch_webapp {app.name!r}")
    browser = ensure_browser()
    cmd = [browser, f"--app={app.url}", "--new-window", f"--class={app.name}"]
    debug(f"launch_webapp cmd={cmd}")
    try:
        subprocess.Popen(cmd)
        gum_style("--foreground", "42", f"Lanzando {app.name}...")
    except Exception as exc:
        debug(f"launch_webapp error: {exc}")
        gum_style("--foreground", "204", f"No se pudo lanzar {app.name}: {exc}")


def delete_webapp_flow() -> None:
    """Elimina una WebApp (JSON + .desktop + icono)."""
    debug("delete_webapp_flow inicio")
    apps = load_webapps()
    if not apps:
        gum_style("--foreground", "214", "No hay WebApps registradas.")
        return

    options = [a.name for a in apps]
    selected = gum_choose(options, "Selecciona la WebApp a eliminar")
    if not selected:
        debug("delete_webapp_flow cancelado por usuario")
        return

    if not gum_confirm(f"¿Eliminar '{selected}'?"):
        debug("delete_webapp_flow: usuario canceló confirmación")
        return

    remaining: List[WebApp] = []
    for app in apps:
        if app.name != selected:
            remaining.append(app)
            continue

        # borrar .desktop
        desktop_path = APPLICATIONS_DIR / f"{sanitize_filename(app.name)}.desktop"
        if desktop_path.exists():
            debug(f"delete_webapp_flow unlink desktop {desktop_path}")
            try:
                desktop_path.unlink()
            except OSError as exc:
                debug(f"Error eliminando .desktop: {exc}")

        # borrar icono
        if app.icon:
            icon_path = ICONS_DIR / app.icon
            if icon_path.exists():
                debug(f"delete_webapp_flow unlink icon {icon_path}")
                try:
                    icon_path.unlink()
                except OSError as exc:
                    debug(f"Error eliminando icono: {exc}")

    save_webapps(remaining)
    gum_style("--foreground", "42", f"WebApp '{selected}' eliminada.")
    debug("delete_webapp_flow fin OK")


def launch_by_name(name: str) -> None:
    """Lanza una WebApp por nombre directo."""
    debug(f"launch_by_name {name!r}")
    apps = load_webapps()
    for app in apps:
        if app.name.lower() == name.lower():
            launch_webapp(app)
            return
    gum_style("--foreground", "204", f"No se encontró la WebApp '{name}'.")


def show_menu() -> None:
    """Menú principal interactivo con gum."""
    debug("show_menu inicio")
    options = [
        "Crear nueva WebApp",
        "Listar y lanzar WebApps",
        "Eliminar WebApp",
        "Salir",
    ]
    mapping = {
        "Crear nueva WebApp": create_webapp_flow,
        "Listar y lanzar WebApps": list_webapps_flow,
        "Eliminar WebApp": delete_webapp_flow,
    }

    while True:
        choice = gum_choose(options, "orgmweb - Gestor de WebApps")
        if not choice or choice == "Salir":
            debug("show_menu salir")
            return
        action = mapping.get(choice)
        if action:
            action()


def usage() -> None:
    """Muestra ayuda básica."""
    debug("usage")
    text = """# orgmweb - Gestor de WebApps

Uso:

```bash
orgmweb               # Menú interactivo
orgmweb create        # Crear nueva WebApp
orgmweb list          # Listar y lanzar WebApps
orgmweb delete        # Eliminar WebApp
orgmweb launch <name> # Lanzar WebApp por nombre
```
"""
    show_markdown(text)


def main() -> None:
    """Punto de entrada principal sin frameworks."""
    debug(f"main argv={sys.argv}")
    ensure_env()

    args = sys.argv[1:]
    if not args:
        show_menu()
        return

    cmd = args[0]
    if cmd in ("-h", "--help", "help"):
        usage()
        return
    if cmd == "create":
        create_webapp_flow()
        return
    if cmd == "list":
        list_webapps_flow()
        return
    if cmd == "delete":
        delete_webapp_flow()
        return
    if cmd == "launch":
        if len(args) < 2:
            gum_style("--foreground", "204", "Uso: orgmweb launch <nombre>")
            return
        launch_by_name(" ".join(args[1:]))
        return

    # Si no coincide ningún comando, tratamos como menú
    show_menu()


if __name__ == "__main__":
    main()
