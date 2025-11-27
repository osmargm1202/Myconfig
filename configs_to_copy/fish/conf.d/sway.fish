function start-sway
    # Wayland
    set -x OZONE_PLATFORM wayland
    set -x QT_QPA_PLATFORM wayland
    set -x GDK_BACKEND wayland
    set -x SDL_VIDEODRIVER wayland
    set -x CLUTTER_BACKEND wayland
    
    # NVIDIA específico
    set -x __GLX_VENDOR_LIBRARY_NAME nvidia
    set -x LIBVA_DRIVER_NAME nvidia
    set -x VDPAU_DRIVER nvidia
    set -x NVD_BACKEND direct
    
    # GPU optimization
    set -x __NV_PRIME_RENDER_OFFLOAD 1
    set -x __VK_LAYER_NV_optimus NVIDIA_only
    set -x LIBGL_ALWAYS_INDIRECT 0
    
    # CRÍTICO para Sway + NVIDIA
    set -x WLR_NO_HARDWARE_CURSORS 1
    set -x GBM_BACKEND nvidia-drm
    
    # Electron apps
    set -x ELECTRON_OZONE_PLATFORM_HINT auto
    
    # Performance
    set -x MESA_NO_ERROR 1
    set -x EGL_PLATFORM wayland
    
    # Ejecutar Sway
    exec sway
end

# Alias corto
alias ss='start-sway'

set TTY1 (tty)
[ "$TTY1" = "/dev/tty3" ] && start-sway