#!/usr/bin/env python3
"""
orgmai - CLI para interactuar con OpenAI ChatGPT
"""

import sys
import subprocess
import os
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime
import re

# Constantes
CONFIG_DIR = Path.home() / ".config" / "orgmai"
CONFIG_FILE = CONFIG_DIR / "config.yaml"
CONVERSATIONS_DIR = CONFIG_DIR / "conversations"
DEFAULT_MODEL = "gpt-5.1-chat-latest"
MAX_CONVERSATIONS = 10

# Modelos disponibles de OpenAI
AVAILABLE_MODELS = [
    "gpt-4o",
    "gpt-4o-mini",
    "gpt-4-turbo",
    "gpt-4",
    "gpt-3.5-turbo",
    "gpt-5.1-chat-latest",
]

# Variables globales para caché
_config_cache = None
_config_file_mtime = None
_openai_client = None


def check_tool(tool: str) -> bool:
    """Verifica si una herramienta está disponible"""
    result = subprocess.run(["which", tool], capture_output=True, check=False)
    return result.returncode == 0


def error_exit(message: str):
    """Muestra error y sale del programa"""
    if check_tool("gum"):
        subprocess.run(["gum", "style", "--foreground", "204", "--bold", message])
    else:
        print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def gum_input(prompt: str = ">") -> Optional[str]:
    """Obtiene input del usuario usando gum"""
    print(f"[DEBUG] gum_input llamado con prompt: '{prompt}'", file=sys.stderr)

    if not check_tool("gum"):
        print("[DEBUG] gum no encontrado", file=sys.stderr)
        error_exit("gum no está instalado. Instala con: paru -S gum")

    print(f"[DEBUG] Ejecutando: gum input --prompt '{prompt}'", file=sys.stderr)

    # Ejecutar gum input de forma interactiva
    # No capturar stderr para que gum pueda mostrar su interfaz
    result = subprocess.run(
        ["gum", "input", "--prompt", prompt],
        stdout=subprocess.PIPE,
        stderr=None,  # Dejar stderr libre para que gum muestre su interfaz
        text=True,
        check=False,
    )

    print(f"[DEBUG] gum input returncode: {result.returncode}", file=sys.stderr)
    print(f"[DEBUG] gum input stdout: '{result.stdout}'", file=sys.stderr)

    # Returncode 130 es Ctrl+C, tratarlo como cancelación
    if result.returncode == 130:
        print("[DEBUG] Usuario canceló con Ctrl+C", file=sys.stderr)
        return None

    output = result.stdout.strip()
    print(f"[DEBUG] gum_input retornando: '{output}'", file=sys.stderr)
    return output if output else None


def gum_choose(options: List[str], prompt: str = "Selecciona:") -> Optional[str]:
    """Muestra opciones usando gum choose"""
    print(
        f"[DEBUG] gum_choose llamado con {len(options)} opciones, prompt: '{prompt}'",
        file=sys.stderr,
    )
    print(f"[DEBUG] Opciones: {options}", file=sys.stderr)

    if not check_tool("gum"):
        print("[DEBUG] gum no encontrado", file=sys.stderr)
        error_exit("gum no está instalado. Instala con: paru -S gum")

    if not options:
        print("[DEBUG] No hay opciones, retornando None", file=sys.stderr)
        return None

    # Escapar opciones que contengan caracteres especiales y pasarlas como argumentos
    # gum choose acepta opciones como argumentos
    cmd = ["gum", "choose"]
    # Agregar cada opción como argumento separado (gum maneja espacios y caracteres especiales)
    cmd.extend(options)
    print(f"[DEBUG] Ejecutando: {' '.join(repr(arg) for arg in cmd)}", file=sys.stderr)

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=None,  # Dejar stderr libre para que gum muestre su interfaz
        text=True,
    )
    stdout, _ = proc.communicate()

    print(f"[DEBUG] gum choose returncode: {proc.returncode}", file=sys.stderr)
    print(f"[DEBUG] gum choose stdout: '{stdout}'", file=sys.stderr)

    # Returncode 130 es Ctrl+C, tratarlo como cancelación
    if proc.returncode == 130:
        print("[DEBUG] Usuario canceló con Ctrl+C", file=sys.stderr)
        return None

    if proc.returncode != 0:
        print(
            f"[DEBUG] gum choose falló con returncode {proc.returncode}, retornando None",
            file=sys.stderr,
        )
        return None

    result = stdout.strip() if stdout else None
    print(f"[DEBUG] gum_choose retornando: '{result}'", file=sys.stderr)
    return result


def gum_confirm(message: str) -> bool:
    """Muestra confirmación usando gum confirm"""
    if not check_tool("gum"):
        error_exit("gum no está instalado. Instala con: paru -S gum")

    result = subprocess.run(
        ["gum", "confirm", message],
        check=False,
    )
    return result.returncode == 0


def show_markdown(text: str):
    """Muestra texto markdown usando bat o less"""
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


def print_info(msg: str):
    """Imprime mensaje informativo"""
    if check_tool("gum"):
        subprocess.run(["gum", "style", "--foreground", "39", msg])
    else:
        print(msg)


def print_success(msg: str):
    """Imprime mensaje de éxito"""
    if check_tool("gum"):
        subprocess.run(["gum", "style", "--foreground", "42", msg])
    else:
        print(msg)


def print_warning(msg: str):
    """Imprime mensaje de advertencia"""
    if check_tool("gum"):
        subprocess.run(["gum", "style", "--foreground", "214", msg])
    else:
        print(msg)


def print_error(msg: str):
    """Imprime mensaje de error"""
    if check_tool("gum"):
        subprocess.run(["gum", "style", "--foreground", "204", "--bold", msg])
    else:
        print(f"ERROR: {msg}", file=sys.stderr)


def load_config() -> Dict:
    """Carga la configuración desde el archivo YAML con caché"""
    global _config_cache, _config_file_mtime

    try:
        import yaml
    except ImportError:
        error_exit("yaml no está instalado. Instala con: pip install pyyaml")

    # Verificar si el archivo existe
    if not CONFIG_FILE.exists():
        _config_cache = {}
        _config_file_mtime = None
        return {}

    # Obtener mtime del archivo
    try:
        current_mtime = CONFIG_FILE.stat().st_mtime
    except OSError:
        current_mtime = None

    # Si el caché es válido, retornarlo
    if _config_cache is not None and _config_file_mtime == current_mtime:
        return _config_cache

    # Cargar configuración desde archivo
    try:
        with open(CONFIG_FILE, "r") as f:
            _config_cache = yaml.safe_load(f) or {}
            _config_file_mtime = current_mtime
            return _config_cache
    except Exception as e:
        print_error(f"Error cargando configuración: {e}")
        _config_cache = {}
        _config_file_mtime = None
        return {}


def save_config(config: Dict):
    """Guarda la configuración en el archivo YAML e invalida el caché"""
    global _config_cache, _config_file_mtime

    try:
        import yaml
    except ImportError:
        error_exit("yaml no está instalado. Instala con: pip install pyyaml")

    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    try:
        with open(CONFIG_FILE, "w") as f:
            yaml.safe_dump(config, f, default_flow_style=False)
        # Invalidar caché
        _config_cache = config
        try:
            _config_file_mtime = CONFIG_FILE.stat().st_mtime
        except OSError:
            _config_file_mtime = None
    except Exception as e:
        print_error(f"Error guardando configuración: {e}")
        sys.exit(1)


def get_api_key() -> str:
    """Obtiene la API key, solicitándola si no existe"""
    config = load_config()
    api_key = config.get("api_key")

    if not api_key:
        print_warning("No se encontró API key de OpenAI")
        api_key = gum_input("Ingrese su OpenAI API Key: ")
        if not api_key:
            error_exit("API key requerida para continuar")
        config["api_key"] = api_key
        save_config(config)
        print_success("API key guardada")

    return api_key


def get_model() -> str:
    """Obtiene el modelo configurado"""
    config = load_config()
    return config.get("model", DEFAULT_MODEL)


def set_model(model: str):
    """Establece el modelo en la configuración"""
    config = load_config()
    config["model"] = model
    save_config(config)
    print_success(f"Modelo configurado: {model}")


def get_client():
    """Obtiene el cliente de OpenAI (con caché)"""
    global _openai_client

    try:
        from openai import OpenAI
    except ImportError:
        error_exit("openai no está instalado. Instala con: pip install openai")

    if _openai_client is None:
        api_key = get_api_key()
        _openai_client = OpenAI(api_key=api_key)
    return _openai_client


def sanitize_filename(title: str) -> str:
    """Sanitiza el título para usarlo como nombre de archivo"""
    title = re.sub(r"[^\w\s-]", "", title)
    title = re.sub(r"[-\s]+", "-", title)
    return title[:50]


def are_words_similar(word1: str, word2: str) -> bool:
    """Verifica si dos palabras son similares (mismo inicio o muy parecidas)"""
    word1_lower = word1.lower()
    word2_lower = word2.lower()

    # Si son iguales (ignorando mayúsculas)
    if word1_lower == word2_lower:
        return True

    # Si una contiene a la otra (palabras muy similares)
    if len(word1_lower) >= 4 and len(word2_lower) >= 4:
        if word1_lower.startswith(word2_lower[:4]) or word2_lower.startswith(
            word1_lower[:4]
        ):
            return True

    return False


def generate_title(messages: List[Dict]) -> str:
    """Genera un título tomando las 3 palabras más grandes del primer prompt, evitando repeticiones"""
    if not messages:
        return "conversacion"

    first_user_message = None
    for msg in messages:
        if msg.get("role") == "user":
            first_user_message = msg.get("content", "")
            break

    if not first_user_message:
        return "conversacion"

    words = first_user_message.split()
    meaningful_words = [
        w.strip(".,!?;:()[]{}\"'")
        for w in words
        if len(w.strip(".,!?;:()[]{}\"'")) >= 3
    ]

    # Ordenar por longitud (más grandes primero)
    meaningful_words.sort(key=len, reverse=True)

    # Seleccionar palabras únicas (no repetidas ni similares)
    title_words = []
    for word in meaningful_words:
        # Verificar si la palabra ya está en title_words o es similar a alguna
        is_duplicate = False
        for existing_word in title_words:
            if are_words_similar(word, existing_word):
                is_duplicate = True
                break

        if not is_duplicate:
            title_words.append(word)
            if len(title_words) >= 3:
                break

    # Si no hay suficientes palabras únicas, usar las primeras palabras del mensaje
    if len(title_words) < 3:
        all_words = first_user_message.split()
        for word in all_words:
            cleaned_word = word.strip(".,!?;:()[]{}\"'")
            if len(cleaned_word) >= 3:
                # Verificar si ya está en title_words
                is_duplicate = False
                for existing_word in title_words:
                    if are_words_similar(cleaned_word, existing_word):
                        is_duplicate = True
                        break

                if not is_duplicate:
                    title_words.append(cleaned_word)
                    if len(title_words) >= 3:
                        break

    title = " ".join(title_words) if title_words else "conversacion"
    return sanitize_filename(title)


def save_conversation(messages: List[Dict], title: str, timestamp: str):
    """Guarda la conversación en un archivo MD"""
    CONVERSATIONS_DIR.mkdir(parents=True, exist_ok=True)

    filename = f"{timestamp}-{title}.md"
    filepath = CONVERSATIONS_DIR / filename

    try:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(f"# {title}\n\n")
            try:
                dt = datetime.strptime(timestamp, "%Y-%m-%d-%H-%M-%S")
                f.write(f"**Fecha:** {dt.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            except Exception:
                f.write(f"**Fecha:** {timestamp}\n\n")
            f.write("---\n\n")

            for msg in messages:
                role = msg["role"]
                content = msg["content"]

                if role == "user":
                    f.write(f"## Usuario\n\n{content}\n\n")
                elif role == "assistant":
                    f.write(f"## Asistente\n\n{content}\n\n")
                f.write("---\n\n")

        manage_conversation_limit()
        print_success(f"Conversación guardada: {filename}")
    except Exception as e:
        print_error(f"Error guardando conversación: {e}")


def load_conversation(filename: str) -> List[Dict]:
    """Carga una conversación desde un archivo MD"""
    filepath = CONVERSATIONS_DIR / filename

    if not filepath.exists():
        return []

    try:
        messages = []
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()

        lines = content.splitlines()

        current_role = None
        current_content = []
        in_content = False

        for line in lines:
            if line.startswith("## Usuario"):
                if current_role and current_content:
                    messages.append(
                        {
                            "role": current_role,
                            "content": "\n".join(current_content).strip(),
                        }
                    )
                current_role = "user"
                current_content = []
                in_content = True
            elif line.startswith("## Asistente"):
                if current_role and current_content:
                    messages.append(
                        {
                            "role": current_role,
                            "content": "\n".join(current_content).strip(),
                        }
                    )
                current_role = "assistant"
                current_content = []
                in_content = True
            elif line.startswith("---"):
                continue
            elif line.startswith("#") or line.startswith("**"):
                continue
            elif in_content and line:
                current_content.append(line)
            elif in_content and not line and current_content:
                current_content.append("")

        if current_role and current_content:
            messages.append(
                {"role": current_role, "content": "\n".join(current_content).strip()}
            )

        return messages
    except Exception as e:
        print_error(f"Error cargando conversación: {e}")
        return []


def list_conversations() -> List[str]:
    """Lista las últimas conversaciones (máximo 10) - optimizado con os.scandir"""
    if not CONVERSATIONS_DIR.exists():
        return []

    files_with_mtime = []
    try:
        with os.scandir(CONVERSATIONS_DIR) as entries:
            for entry in entries:
                if entry.is_file() and entry.name.endswith(".md"):
                    try:
                        stat = entry.stat()
                        files_with_mtime.append((entry.name, stat.st_mtime))
                    except OSError:
                        continue
    except OSError:
        return []

    files_with_mtime.sort(key=lambda x: x[1], reverse=True)
    return [name for name, _ in files_with_mtime[:MAX_CONVERSATIONS]]


def manage_conversation_limit():
    """Elimina la conversación más antigua si hay más de MAX_CONVERSATIONS"""
    if not CONVERSATIONS_DIR.exists():
        return

    files_with_mtime = []
    try:
        with os.scandir(CONVERSATIONS_DIR) as entries:
            for entry in entries:
                if entry.is_file() and entry.name.endswith(".md"):
                    try:
                        stat = entry.stat()
                        files_with_mtime.append((entry.path, stat.st_mtime))
                    except OSError:
                        continue
    except OSError:
        return

    if len(files_with_mtime) > MAX_CONVERSATIONS:
        files_with_mtime.sort(key=lambda x: x[1])
        oldest_path = files_with_mtime[0][0]
        try:
            os.unlink(oldest_path)
            print_warning(
                f"Conversación antigua eliminada: {os.path.basename(oldest_path)}"
            )
        except Exception as e:
            print_error(f"Error eliminando conversación antigua: {e}")


def stream_chat(client, messages: List[Dict], model: str):
    """Envía mensajes a OpenAI y muestra la respuesta en markdown"""
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=messages,
        )

        content = resp.choices[0].message.content or ""

        if content:
            show_markdown(content)

        return content

    except Exception as e:
        print_error(f"Error en la solicitud: {e}")
        return None


def chat(ctx=None):
    """Inicia una nueva conversación con la IA"""
    print("[DEBUG] chat() llamado", file=sys.stderr)
    args = sys.argv[1:]
    print(f"[DEBUG] args: {args}", file=sys.stderr)

    chat_idx = -1
    for i, arg in enumerate(args):
        if arg == "chat":
            chat_idx = i
            break

    if chat_idx >= 0:
        remaining_args = args[chat_idx + 1 :]
    else:
        remaining_args = args

    pregunta_parts = []
    for arg in remaining_args:
        if arg.startswith("--"):
            continue
        pregunta_parts.append(arg)

    pregunta = " ".join(pregunta_parts) if pregunta_parts else None
    print(f"[DEBUG] pregunta: '{pregunta}'", file=sys.stderr)

    client = get_client()
    model = get_model()

    if not pregunta:
        print("[DEBUG] Modo interactivo iniciado", file=sys.stderr)
        messages = []
        now = datetime.now()
        timestamp = now.strftime("%Y-%m-%d-%H-%M-%S")

        print_info(f"Modelo: {model}\n")

        while True:
            print("[DEBUG] Esperando input del usuario...", file=sys.stderr)
            user_input = gum_input("Tú>")
            print(f"[DEBUG] Usuario ingresó: '{user_input}'", file=sys.stderr)

            if not user_input or user_input.lower() in ["salir", "exit", "quit"]:
                break

            messages.append({"role": "user", "content": user_input})
            print_info("\nRespuesta:\n")

            response = stream_chat(client, messages, model)

            if response:
                messages.append({"role": "assistant", "content": response})
                if len(messages) == 2:
                    title = generate_title(messages)
                    save_conversation(messages, title, timestamp)
                else:
                    filepath = CONVERSATIONS_DIR / f"{timestamp}-{title}.md"
                    if filepath.exists():
                        save_conversation(messages, title, timestamp)
        return

    messages = [{"role": "user", "content": pregunta}]
    now = datetime.now()
    timestamp = now.strftime("%Y-%m-%d-%H-%M-%S")

    print_info(f"Modelo: {model}\n")
    print_info("Respuesta:\n")

    response = stream_chat(client, messages, model)

    if response:
        messages.append({"role": "assistant", "content": response})
        title = generate_title(messages)
        save_conversation(messages, title, timestamp)

        while True:
            print()
            user_input = gum_input("Tú>")

            if not user_input or user_input.lower() in ["salir", "exit", "quit"]:
                break

            messages.append({"role": "user", "content": user_input})
            print_info("\nRespuesta:\n")

            response = stream_chat(client, messages, model)

            if response:
                messages.append({"role": "assistant", "content": response})
                filepath = CONVERSATIONS_DIR / f"{timestamp}-{title}.md"
                if filepath.exists():
                    save_conversation(messages, title, timestamp)


def config():
    """Configura el modelo a utilizar"""
    print("[DEBUG] config() llamado", file=sys.stderr)
    print_info("Selecciona el modelo a utilizar:\n")

    current_model = get_model()
    print(f"[DEBUG] Modelo actual: {current_model}", file=sys.stderr)
    choices = []

    for model in AVAILABLE_MODELS:
        label = model
        if model == current_model:
            label += " (actual)"
        choices.append(label)

    print(f"[DEBUG] Opciones para elegir: {choices}", file=sys.stderr)
    selected = gum_choose(choices, "Modelo:")
    print(f"[DEBUG] Opción seleccionada: '{selected}'", file=sys.stderr)

    if selected:
        model_name = selected.split(" (actual)")[0]
        print(f"[DEBUG] Configurando modelo: {model_name}", file=sys.stderr)
        set_model(model_name)


def last():
    """Continúa la última conversación"""
    conversations = list_conversations()

    if not conversations:
        print_warning("No hay conversaciones anteriores")
        return

    filename = conversations[0]

    messages = load_conversation(filename)

    if not messages:
        print_error("Error cargando la conversación")
        return

    parts = filename.replace(".md", "").split("-", 4)
    timestamp = "-".join(parts[:4])
    title = "-".join(parts[4:]) if len(parts) >= 5 else "conversacion"

    filepath = CONVERSATIONS_DIR / filename
    try:
        # Usar bat para mostrar la conversación en la terminal (prioridad)
        if check_tool("bat"):
            subprocess.run(["bat", str(filepath)], check=False)
        elif check_tool("less"):
            subprocess.run(["less", "-R", str(filepath)], check=False)
        elif check_tool("gum"):
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
            proc = subprocess.Popen(
                ["gum", "pager"],
                stdin=subprocess.PIPE,
                text=True,
            )
            proc.communicate(content)
        else:
            with open(filepath, "r", encoding="utf-8") as f:
                print(f.read())
    except Exception as e:
        print_error(f"Error mostrando conversación: {e}")
        return

    client = get_client()
    model = get_model()

    print_info(f"\nModelo: {model}")
    print_info(f"Conversación: {title}\n")

    while True:
        user_input = gum_input("Tú>")

        if not user_input or user_input.lower() in ["salir", "exit", "quit"]:
            break

        messages.append({"role": "user", "content": user_input})
        print_info("\nRespuesta:\n")

        response = stream_chat(client, messages, model)

        if response:
            messages.append({"role": "assistant", "content": response})
            save_conversation(messages, title, timestamp)


def prev():
    """Selecciona y continúa una conversación anterior"""
    print("[DEBUG] prev() llamado", file=sys.stderr)
    conversations = list_conversations()
    print(f"[DEBUG] Conversaciones encontradas: {len(conversations)}", file=sys.stderr)

    if not conversations:
        print_warning("No hay conversaciones anteriores")
        return

    print_info("Selecciona una conversación para continuar:\n")

    choices = []
    for conv in conversations:
        parts = conv.replace(".md", "").split("-", 4)
        if len(parts) >= 5:
            title = "-".join(parts[4:])
            date_str = f"{parts[0]}-{parts[1]}-{parts[2]} {parts[3]}"
            choices.append(f"{title} ({date_str})")
        else:
            choices.append(conv)

    print(f"[DEBUG] Opciones para elegir: {choices}", file=sys.stderr)
    selected = gum_choose(choices, "Conversación:")
    print(f"[DEBUG] Opción seleccionada: '{selected}'", file=sys.stderr)

    if not selected:
        print("[DEBUG] No se seleccionó ninguna opción", file=sys.stderr)
        return

    idx = choices.index(selected)
    filename = conversations[idx]

    messages = load_conversation(filename)

    if not messages:
        print_error("Error cargando la conversación")
        return

    parts = filename.replace(".md", "").split("-", 4)
    timestamp = "-".join(parts[:4])
    title = "-".join(parts[4:]) if len(parts) >= 5 else "conversacion"

    filepath = CONVERSATIONS_DIR / filename
    try:
        # Usar gum pager si está disponible, sino less, sino bat, sino cat
        if check_tool("gum"):
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
            proc = subprocess.Popen(
                ["gum", "pager"],
                stdin=subprocess.PIPE,
                text=True,
            )
            proc.communicate(content)
        elif check_tool("less"):
            subprocess.run(["less", "-R", str(filepath)], check=False)
        elif check_tool("bat"):
            subprocess.run(["bat", str(filepath)], check=False)
        else:
            with open(filepath, "r", encoding="utf-8") as f:
                print(f.read())
    except Exception as e:
        print_error(f"Error mostrando conversación: {e}")
        return

    client = get_client()
    model = get_model()

    print_info(f"\nModelo: {model}")
    print_info(f"Conversación: {title}\n")

    while True:
        user_input = gum_input("Tú>")

        if not user_input or user_input.lower() in ["salir", "exit", "quit"]:
            break

        messages.append({"role": "user", "content": user_input})
        print_info("\nRespuesta:\n")

        response = stream_chat(client, messages, model)

        if response:
            messages.append({"role": "assistant", "content": response})
            save_conversation(messages, title, timestamp)


def find(termino: str):
    """Busca un término en las últimas conversaciones usando ripgrep"""
    conversations = list_conversations()

    if not conversations:
        print_warning("No hay conversaciones anteriores")
        return

    if not CONVERSATIONS_DIR.exists():
        print_warning("No hay conversaciones para buscar")
        return

    if not check_tool("rg"):
        error_exit("ripgrep (rg) no está instalado. Instala con: paru -S ripgrep")

    try:
        result = subprocess.run(
            [
                "rg",
                "--hidden",
                "-n",
                "--heading",
                "--glob",
                "!.git/*",
                "-i",
                "-C",
                "4",
                termino,
                str(CONVERSATIONS_DIR),
            ],
            capture_output=True,
            text=True,
            check=False,
        )

        if result.returncode == 0:
            # Usar gum pager para mostrar resultados
            if check_tool("gum"):
                proc = subprocess.Popen(
                    ["gum", "pager"],
                    stdin=subprocess.PIPE,
                    text=True,
                )
                proc.communicate(result.stdout)
            elif check_tool("less"):
                proc = subprocess.Popen(
                    ["less", "-R"],
                    stdin=subprocess.PIPE,
                    text=True,
                )
                proc.communicate(result.stdout)
            else:
                print_info(f"Resultados de búsqueda para: {termino}\n")
                print(result.stdout)
        elif result.returncode == 1:
            print_warning(f"No se encontraron resultados para: {termino}")
        else:
            print_error(f"Error ejecutando búsqueda: {result.stderr}")
    except Exception as e:
        print_error(f"Error en la búsqueda: {e}")


def apikey():
    """Configura la API key de OpenAI"""
    print_info("Configura tu API key de OpenAI\n")

    api_key = gum_input("Ingrese su OpenAI API Key: ")
    if not api_key:
        print_warning("Operación cancelada")
        return

    config = load_config()
    config["api_key"] = api_key
    save_config(config)
    print_success("API key guardada correctamente")


def main():
    """Función principal - maneja argumentos sin typer"""
    args = sys.argv[1:]

    if not args:
        print("orgmai - CLI para interactuar con OpenAI ChatGPT\n")
        print("Uso:")
        print("  orgmai chat [pregunta]  - Inicia una conversación")
        print("  orgmai last             - Continúa la última conversación")
        print("  orgmai prev             - Selecciona y continúa una conversación")
        print("  orgmai find <término>   - Busca en conversaciones")
        print("  orgmai config           - Configura el modelo")
        print("  orgmai apikey           - Configura la API key")
        return

    command = args[0]

    if command == "chat":
        chat()
    elif command == "config":
        config()
    elif command == "last":
        last()
    elif command == "prev":
        prev()
    elif command == "find":
        if len(args) < 2:
            print_error("find requiere un término de búsqueda")
            print("Uso: orgmai find <término>")
            sys.exit(1)
        find(args[1])
    elif command == "apikey":
        apikey()
    else:
        # Es una pregunta directa (sin comando)
        chat()


if __name__ == "__main__":
    main()
