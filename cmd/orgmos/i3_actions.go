package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

// ============ WALLPAPER ============

func runChangeWallpaper(cmd *cobra.Command, args []string) {
	logger.InitOnError("change-wallpaper")

	homeDir, _ := os.UserHomeDir()
	lastWallpaperFile := filepath.Join(homeDir, ".lastwallpaper")
	picturesDir := filepath.Join(homeDir, "Pictures", "Wallpapers")
	
	// Descargar/actualizar archivos de config si es necesario
	if err := utils.DownloadConfigFiles(); err != nil {
		// No es crítico para cambiar wallpaper, continuar
	}
	
	repoDir := utils.GetConfigRepoDir()
	if repoDir == "" {
		repoDir = utils.GetRepoDir()
	}
	repoWallpapers := filepath.Join(repoDir, "Wallpapers")

	wallpaperDir := picturesDir
	if _, err := os.Stat(wallpaperDir); os.IsNotExist(err) {
		if _, repoErr := os.Stat(repoWallpapers); repoErr == nil {
			fmt.Println(ui.Warning("No se encontró ~/Pictures/Wallpapers, usando los del repositorio. Ejecuta 'orgmos assets' para copiarlos."))
			wallpaperDir = repoWallpapers
		} else {
			fmt.Println(ui.Error("No se encontró ninguna carpeta de wallpapers. Ejecuta 'orgmos assets' para instalarlos."))
			return
		}
	}

	action := "random"
	if len(args) > 0 && strings.TrimSpace(args[0]) != "" {
		action = args[0]
	}

	setWallpaper := func(path string) {
		if _, err := os.Stat(path); err != nil {
			fmt.Println(ui.Error("Wallpaper no encontrado: " + path))
			return
		}
		if err := applyI3Wallpaper(path); err != nil {
			fmt.Println(ui.Error(fmt.Sprintf("No se pudo aplicar el wallpaper: %v", err)))
			return
		}
		os.WriteFile(lastWallpaperFile, []byte(path), 0o644)
		fmt.Println(ui.Success("Wallpaper cambiado: " + filepath.Base(path)))
	}

	switch action {
	case "random":
		wallpapers, err := listWallpapers(wallpaperDir)
		if err != nil {
			fmt.Println(ui.Error(err.Error()))
			return
		}
		if len(wallpapers) == 0 {
			fmt.Println(ui.Error("No hay wallpapers disponibles"))
			return
		}
		idx := time.Now().UnixNano() % int64(len(wallpapers))
		setWallpaper(wallpapers[idx])

	case "restore":
		data, err := os.ReadFile(lastWallpaperFile)
		if err != nil {
			fmt.Println(ui.Warning("No hay wallpaper anterior guardado, seleccionando uno aleatorio..."))
			wallpapers, err := listWallpapers(wallpaperDir)
			if err != nil || len(wallpapers) == 0 {
				fmt.Println(ui.Error("No hay wallpapers disponibles"))
				return
			}
			idx := time.Now().UnixNano() % int64(len(wallpapers))
			setWallpaper(wallpapers[idx])
			return
		}
		setWallpaper(strings.TrimSpace(string(data)))

	default:
		setWallpaper(action)
	}
}

func listWallpapers(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}

	var wallpapers []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		ext := strings.ToLower(filepath.Ext(e.Name()))
		if ext == ".jpg" || ext == ".jpeg" || ext == ".png" {
			wallpapers = append(wallpapers, filepath.Join(dir, e.Name()))
		}
	}
	return wallpapers, nil
}

func applyI3Wallpaper(path string) error {
	// Usar pywal para generar colores
	if !utils.CheckDependency("wal") {
		return fmt.Errorf("pywal no está instalado. Instala con: sudo pacman -S python-pywal")
	}

	// Generar colores con pywal (sin aplicar wallpaper, solo colores)
	if err := exec.Command("wal", "-i", path, "-n").Run(); err != nil {
		return fmt.Errorf("error ejecutando wal: %w", err)
	}

	// Aplicar wallpaper con xwallpaper o feh
	if utils.CheckDependency("xwallpaper") {
		if err := exec.Command("xwallpaper", "--zoom", path).Run(); err != nil {
			return fmt.Errorf("error aplicando wallpaper con xwallpaper: %w", err)
		}
	} else if utils.CheckDependency("feh") {
		if err := exec.Command("feh", "--bg-fill", path).Run(); err != nil {
			return fmt.Errorf("error aplicando wallpaper con feh: %w", err)
		}
	} else {
		return fmt.Errorf("instala xwallpaper o feh para aplicar wallpapers")
	}

	// Cargar colores en xrdb para polybar
	homeDir, _ := os.UserHomeDir()
	xresourcesPath := filepath.Join(homeDir, ".cache", "wal", "colors.Xresources")
	if _, err := os.Stat(xresourcesPath); err == nil {
		exec.Command("xrdb", "-merge", xresourcesPath).Run()
	}

	// Recargar polybar
	exec.Command("polybar-msg", "cmd", "restart").Run()

	return nil
}

// ============ LOCK ============

func runLock(cmd *cobra.Command, args []string) {
	logger.InitOnError("lock")

	if !utils.RequireDependency("i3lock") {
		fmt.Println(ui.Error("Dependencia faltante: i3lock. Instálala con: sudo pacman -S i3lock-color"))
		return
	}

	exec.Command("i3lock", "--blur", "5", "--clock", "--date-str", "%A, %B %d", "--time-str", "%I:%M %p").Run()
}

// ============ HOTKEY ============

func runHotkey(cmd *cobra.Command, args []string) {
	logger.InitOnError("hotkey")
	showI3Hotkeys()
}

func showI3Hotkeys() {
	homeDir, _ := os.UserHomeDir()
	configFile := filepath.Join(homeDir, ".config", "i3", "config")

	data, err := os.ReadFile(configFile)
	if err != nil {
		fmt.Println(ui.Error("No se pudo leer la configuración de i3"))
		return
	}

	var hotkeys []string
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "bindsym") && !strings.HasPrefix(line, "#") {
			parts := strings.SplitN(line, " ", 3)
			if len(parts) >= 3 {
				key := strings.ReplaceAll(parts[1], "$mod", "Super")
				key = strings.ReplaceAll(key, "+", " + ")
				action := parts[2]
				hotkeys = append(hotkeys, fmt.Sprintf("%s → %s", key, action))
			}
		}
	}

	if len(hotkeys) == 0 {
		fmt.Println(ui.Warning("No se encontraron atajos de teclado"))
		return
	}

	// Mostrar con rofi
	rofiInput := strings.Join(hotkeys, "\n")
	rofiCmd := exec.Command("rofi", "-dmenu", "-i", "-p", "Atajos de Teclado", "-theme-str", "window {width: 50%;} listview {lines: 15;}")
	rofiCmd.Stdin = strings.NewReader(rofiInput)
	rofiCmd.Run()
}

// ============ POWER MENU ============

func runPowerMenu(cmd *cobra.Command, args []string) {
	logger.InitOnError("powermenu")

	options := "⏻ Apagar\n⟳ Reiniciar\n⏾ Suspender\n🔒 Bloquear\n⇥ Cerrar sesión"
	rofiCmd := exec.Command("rofi", "-dmenu", "-i", "-p", "Power", "-theme-str", "window {width: 20%;} listview {lines: 5;}")
	rofiCmd.Stdin = strings.NewReader(options)
	choice, err := rofiCmd.Output()
	if err != nil {
		return
	}

	choiceStr := strings.TrimSpace(string(choice))
	switch {
	case strings.Contains(choiceStr, "Apagar"):
		exec.Command("systemctl", "poweroff").Run()
	case strings.Contains(choiceStr, "Reiniciar"):
		exec.Command("systemctl", "reboot").Run()
	case strings.Contains(choiceStr, "Suspender"):
		exec.Command("systemctl", "suspend").Run()
	case strings.Contains(choiceStr, "Bloquear"):
		runLock(nil, nil)
	case strings.Contains(choiceStr, "Cerrar sesión"):
		exec.Command("i3-msg", "exit").Run()
	}
}

// ============ MEMORY ============

func runMemory(cmd *cobra.Command, args []string) {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		fmt.Println("?")
		return
	}

	var total, available float64
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "MemTotal:") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				val, _ := strconv.ParseFloat(parts[1], 64)
				total = val / 1024 / 1024
			}
		} else if strings.HasPrefix(line, "MemAvailable:") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				val, _ := strconv.ParseFloat(parts[1], 64)
				available = val / 1024 / 1024
			}
		}
	}

	used := total - available
	fmt.Printf(" %.1fG\n", used)
}

// ============ RELOAD ============

func runReload(cmd *cobra.Command, args []string) {
	logger.InitOnError("reload")

	fmt.Println(ui.Info("Recargando i3 y polybar..."))

	// Recargar i3
	if err := exec.Command("i3-msg", "reload").Run(); err != nil {
		fmt.Println(ui.Warning("No se pudo recargar i3 (puede que no esté corriendo)"))
	} else {
		fmt.Println(ui.Success("i3 recargado"))
	}

	// Matar polybar si existe
	exec.Command("killall", "-q", "polybar").Run()
	
	// Esperar 0.5 segundos para asegurar que se cierre correctamente
	fmt.Println(ui.Info("Esperando 0.5 segundos..."))
	time.Sleep(500 * time.Millisecond)

	// Lanzar polybar
	homeDir, _ := os.UserHomeDir()
	polybarConfig := filepath.Join(homeDir, ".config", "polybar", "config.ini")
	if err := exec.Command("polybar", "--config="+polybarConfig, "modern").Start(); err != nil {
		fmt.Println(ui.Warning("No se pudo lanzar polybar"))
	} else {
		fmt.Println(ui.Success("polybar lanzado"))
	}

	fmt.Println(ui.Success("Recarga completada"))
}
