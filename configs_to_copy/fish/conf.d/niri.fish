# Iniciar Niri automáticamente al hacer login en TTY1
if status is-login
    if test -z "$DISPLAY" -a "$XDG_VTNR" -eq 1
        # --- Forzar backend X11 / XWayland ---
        set -x OZONE_PLATFORM x11
        set -x QT_QPA_PLATFORM wayland
        set -x GDK_BACKEND x11
        set -x EGL_PLATFORM x11
        set -x ELECTRON_OZONE_PLATFORM_HINT x11

        # --- NVIDIA ---
        set -x __GLX_VENDOR_LIBRARY_NAME nvidia
        set -x LIBVA_DRIVER_NAME nvidia
        set -x VDPAU_DRIVER nvidia
        set -x __NV_PRIME_RENDER_OFFLOAD 1
        set -x LIBGL_ALWAYS_INDIRECT 0

        # --- Optimizaciones ---
        set -x MESA_NO_ERROR 1

        # --- Flatpak / XDG ---
        #set -x XDG_DATA_DIRS $HOME/.local/share/flatpak/exports/share/applications:/var/lib/flatpak/exports/share/applications:$XDG_DATA_DIRS
        exec niri
    end
end
