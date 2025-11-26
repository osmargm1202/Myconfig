# Configuración de Fish como login shell y inicio automático de Niri/i3

## 1. Configurar Fish como login shell (shell de inicio de sesión)

```bash
chsh -s /usr/bin/fish
```

**Importante:** Después de ejecutar este comando, necesitas **cerrar sesión completamente** y volver a iniciar sesión para que el cambio tome efecto. Fish será ahora el shell que se ejecuta automáticamente cuando inicies sesión en TTY.

## 2. Configurar inicio automático de Niri o i3

Una vez que fish sea tu login shell, edita el archivo: `~/.config/fish/config.fish`

### Para iniciar Niri automáticamente en TTY1:

```fish
# Iniciar Niri automáticamente al hacer login en TTY1
if status is-login
    if test -z "$DISPLAY" -a "$XDG_VTNR" -eq 1
        exec niri-session
    end
end
```

### Para iniciar i3 automáticamente en TTY1:

```fish
# Iniciar i3 automáticamente al hacer login en TTY1
if status is-login
    if test -z "$DISPLAY" -a "$XDG_VTNR" -eq 1
        exec startx
    end
end
```

Si usas startx para i3, también crea/edita `~/.xinitrc`:

```bash
exec i3
```

## 3. Verificar el cambio

Para verificar que fish es tu login shell:

```bash
echo $SHELL
```

Debe mostrar: `/usr/bin/fish`

## Explicación:

- `chsh -s /usr/bin/fish` cambia tu login shell a fish
- `status is-login` verifica que sea un login shell (el que inicia al hacer login)
- `test -z "$DISPLAY"` verifica que no haya sesión gráfica ya iniciada
- `"$XDG_VTNR" -eq 1` asegura que solo se ejecute en TTY1
- `exec` reemplaza el proceso del shell con niri-session o startx
