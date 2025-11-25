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
)

var scriptCmd = &cobra.Command{
	Use:   "script [comando]",
	Short: "Ejecutar scripts de automatización",
	Long: `Ejecuta scripts de automatización disponibles:

  i3/Wayland:
    caffeine       - Prevenir suspensión del sistema
    game-mode      - Activar/desactivar modo juego
    lock           - Bloquear pantalla
    change-wallpaper - Cambiar wallpaper
    hotkey         - Mostrar atajos de teclado
    monitor-watcher  - Monitorear cambios de monitores

  Polybar:
    paru-updates   - Mostrar/actualizar paquetes AUR
    flatpak-updates - Mostrar/actualizar Flatpak
    powermenu      - Menú de energía
    memory         - Mostrar uso de memoria
    keyboard-toggle - Cambiar idioma de teclado`,
	Run: func(cmd *cobra.Command, args []string) {
		cmd.Help()
	},
}

func init() {
	rootCmd.AddCommand(scriptCmd)

	// Scripts de i3
	scriptCmd.AddCommand(&cobra.Command{
		Use:   "caffeine [toggle|enable|disable|status]",
		Short: "Prevenir suspensión del sistema",
		Run:   runCaffeine,
	})

	scriptCmd.AddCommand(&cobra.Command{
		Use:   "game-mode [reload]",
		Short: "Activar/desactivar modo juego",
		Run:   runGameMode,
	})

	scriptCmd.AddCommand(&cobra.Command{
		Use:   "lock",
		Short: "Bloquear pantalla",
		Run:   runLock,
	})

	scriptCmd.AddCommand(&cobra.Command{
		Use:   "change-wallpaper [random|restore]",
		Short: "Cambiar wallpaper",
		Run:   runChangeWallpaper,
	})

	scriptCmd.AddCommand(&cobra.Command{
		Use:   "hotkey",
		Short: "Mostrar atajos de teclado",
		Run:   runHotkey,
	})

	scriptCmd.AddCommand(&cobra.Command{
		Use:   "monitor-watcher",
		Short: "Monitorear cambios de monitores",
		Run:   runMonitorWatcher,
	})

	// Scripts de Polybar
	scriptCmd.AddCommand(&cobra.Command{
		Use:   "paru-updates [update]",
		Short: "Mostrar/actualizar paquetes AUR con paru",
		Run:   runParuUpdates,
	})

	scriptCmd.AddCommand(&cobra.Command{
		Use:   "flatpak-updates [update]",
		Short: "Mostrar/actualizar aplicaciones Flatpak",
		Run:   runFlatpakUpdates,
	})

	scriptCmd.AddCommand(&cobra.Command{
		Use:   "powermenu",
		Short: "Menú de energía",
		Run:   runPowerMenu,
	})

	scriptCmd.AddCommand(&cobra.Command{
		Use:   "memory",
		Short: "Mostrar uso de memoria",
		Run:   runMemory,
	})

	scriptCmd.AddCommand(&cobra.Command{
		Use:   "keyboard-toggle",
		Short: "Cambiar idioma de teclado",
		Run:   runKeyboardToggle,
	})
}

// ============ CAFFEINE ============

func runCaffeine(cmd *cobra.Command, args []string) {
	logger.Init("caffeine")
	defer logger.Close()

	homeDir, _ := os.UserHomeDir()
	stateFile := filepath.Join(homeDir, ".config", "i3", "caffeine_state")

	action := "toggle"
	if len(args) > 0 {
		action = args[0]
	}

	// Leer estado actual
	getState := func() string {
		data, err := os.ReadFile(stateFile)
		if err != nil {
			return "enabled"
		}
		return strings.TrimSpace(string(data))
	}

	// Guardar estado
	setState := func(state string) {
		os.MkdirAll(filepath.Dir(stateFile), 0755)
		os.WriteFile(stateFile, []byte(state), 0644)
	}

	// Activar caffeine
	enableCaffeine := func() {
		exec.Command("xset", "-dpms").Run()
		exec.Command("xset", "s", "off").Run()
		exec.Command("pkill", "-x", "xss-lock").Run()
		exec.Command("pkill", "-x", "xautolock").Run()
		setState("enabled")
		exec.Command("polybar-msg", "hook", "caffeine", "1").Run()
		exec.Command("notify-send", "-u", "low", "Cafeína", "Modo cafeína activado").Run()
		fmt.Println("☕ Modo cafeína activado")
	}

	// Desactivar caffeine
	disableCaffeine := func() {
		exec.Command("xset", "+dpms").Run()
		exec.Command("xset", "s", "300", "5").Run()
		exec.Command("xset", "dpms", "600", "1200", "1800").Run()
		
		// Iniciar xautolock si no está corriendo
		if exec.Command("pgrep", "-x", "xautolock").Run() != nil {
			exec.Command("xautolock", "-time", "5", "-locker", "i3lock --blur 5", "-detectsleep").Start()
		}
		
		// Iniciar xss-lock si no está corriendo
		if exec.Command("pgrep", "-x", "xss-lock").Run() != nil {
			exec.Command("xss-lock", "--transfer-sleep-lock", "--", "i3lock", "--blur", "5").Start()
		}
		
		setState("disabled")
		exec.Command("polybar-msg", "hook", "caffeine", "1").Run()
		exec.Command("notify-send", "-u", "low", "Cafeína", "Modo cafeína desactivado").Run()
		fmt.Println("💤 Modo cafeína desactivado")
	}

	switch action {
	case "toggle":
		if getState() == "enabled" {
			disableCaffeine()
		} else {
			enableCaffeine()
		}
	case "enable":
		enableCaffeine()
	case "disable":
		disableCaffeine()
	case "status":
		fmt.Println(getState())
	case "apply":
		if getState() == "enabled" {
			enableCaffeine()
		} else {
			disableCaffeine()
		}
	default:
		fmt.Println("Uso: orgmos script caffeine [toggle|enable|disable|status|apply]")
	}
}

// ============ GAME MODE ============

func runGameMode(cmd *cobra.Command, args []string) {
	logger.Init("game-mode")
	defer logger.Close()

	homeDir, _ := os.UserHomeDir()
	picomConfig := filepath.Join(homeDir, ".config", "picom", "picom.conf")
	polybarConfig := filepath.Join(homeDir, ".config", "polybar", "config.ini")

	isRunning := func(process string) bool {
		return exec.Command("pgrep", "-x", process).Run() == nil
	}

	stopProcess := func(process string) {
		if isRunning(process) {
			exec.Command("killall", "-q", process).Run()
			time.Sleep(200 * time.Millisecond)
			fmt.Printf("🛑 %s detenido\n", process)
		}
	}

	startPicom := func() {
		if _, err := os.Stat(picomConfig); err == nil {
			exec.Command("picom", "--config", picomConfig, "-b").Start()
		} else {
			exec.Command("picom", "-b").Start()
		}
		time.Sleep(200 * time.Millisecond)
		if isRunning("picom") {
			fmt.Println("✅ Picom iniciado")
		}
	}

	startPolybar := func() {
		if _, err := os.Stat(polybarConfig); err == nil {
			exec.Command("polybar", "--config="+polybarConfig, "modern").Start()
		} else {
			exec.Command("polybar").Start()
		}
		time.Sleep(200 * time.Millisecond)
		if isRunning("polybar") {
			fmt.Println("✅ Polybar iniciado")
		}
	}

	applyOptimizations := func() {
		fmt.Println("🎮 Aplicando optimizaciones para juegos...")
		exec.Command("sudo", "cpupower", "frequency-set", "-g", "performance").Run()
	}

	revertOptimizations := func() {
		fmt.Println("🔄 Revirtiendo optimizaciones...")
		exec.Command("sudo", "cpupower", "frequency-set", "-g", "ondemand").Run()
	}

	// Reload mode
	if len(args) > 0 && args[0] == "reload" {
		fmt.Println("🔄 Modo RELOAD: Reiniciando servicios...")
		stopProcess("picom")
		stopProcess("polybar")
		startPicom()
		startPolybar()
		exec.Command("notify-send", "Modo Juego", "Servicios reiniciados 🔄").Run()
		return
	}

	// Toggle mode
	picomRunning := isRunning("picom")
	polybarRunning := isRunning("polybar")

	if picomRunning && polybarRunning {
		fmt.Println("🎮 ACTIVANDO MODO JUEGO...")
		stopProcess("picom")
		stopProcess("polybar")
		applyOptimizations()
		exec.Command("notify-send", "Modo Juego", "ACTIVADO 🎮").Run()
	} else if !picomRunning && !polybarRunning {
		fmt.Println("🖥️  DESACTIVANDO MODO JUEGO...")
		revertOptimizations()
		startPicom()
		startPolybar()
		exec.Command("notify-send", "Modo Juego", "DESACTIVADO 🖥️").Run()
	} else {
		fmt.Println("⚖️  NORMALIZANDO ESTADO...")
		if !picomRunning {
			startPicom()
		}
		if !polybarRunning {
			startPolybar()
		}
		revertOptimizations()
		exec.Command("notify-send", "Modo Juego", "Estado normalizado ⚖️").Run()
	}

	fmt.Printf("\nEstado final:\n")
	fmt.Printf("  Picom: %s\n", map[bool]string{true: "🟢 Activo", false: "🔴 Inactivo"}[isRunning("picom")])
	fmt.Printf("  Polybar: %s\n", map[bool]string{true: "🟢 Activo", false: "🔴 Inactivo"}[isRunning("polybar")])
}

// ============ LOCK ============

func runLock(cmd *cobra.Command, args []string) {
	logger.Init("lock")
	defer logger.Close()

	// Verificar si caffeine está activado
	homeDir, _ := os.UserHomeDir()
	stateFile := filepath.Join(homeDir, ".config", "i3", "caffeine_state")
	data, _ := os.ReadFile(stateFile)
	if strings.TrimSpace(string(data)) == "enabled" {
		fmt.Println("⚠️ Cafeína activada, no se bloqueará la pantalla")
		return
	}

	// Bloquear con i3lock
	exec.Command("i3lock", "--blur", "5", "--clock", "--date-str", "%A, %B %d", "--time-str", "%I:%M %p").Run()
}

// ============ CHANGE WALLPAPER ============

func runChangeWallpaper(cmd *cobra.Command, args []string) {
	logger.Init("change-wallpaper")
	defer logger.Close()

	homeDir, _ := os.UserHomeDir()
	wallpaperDir := filepath.Join(homeDir, "Pictures", "Wallpapers")
	lastWallpaperFile := filepath.Join(homeDir, ".config", "i3", "last_wallpaper")

	action := "random"
	if len(args) > 0 {
		action = args[0]
	}

	setWallpaper := func(path string) {
		if _, err := os.Stat(path); err != nil {
			fmt.Println(ui.Error("Wallpaper no encontrado: " + path))
			return
		}
		exec.Command("xwallpaper", "--zoom", path).Run()
		os.WriteFile(lastWallpaperFile, []byte(path), 0644)
		fmt.Println(ui.Success("Wallpaper cambiado: " + filepath.Base(path)))
	}

	switch action {
	case "random":
		entries, err := os.ReadDir(wallpaperDir)
		if err != nil {
			fmt.Println(ui.Error("No se encontró el directorio de wallpapers"))
			return
		}

		var wallpapers []string
		for _, e := range entries {
			if !e.IsDir() {
				ext := strings.ToLower(filepath.Ext(e.Name()))
				if ext == ".jpg" || ext == ".jpeg" || ext == ".png" {
					wallpapers = append(wallpapers, filepath.Join(wallpaperDir, e.Name()))
				}
			}
		}

		if len(wallpapers) == 0 {
			fmt.Println(ui.Error("No hay wallpapers disponibles"))
			return
		}

		// Seleccionar aleatorio
		idx := time.Now().UnixNano() % int64(len(wallpapers))
		setWallpaper(wallpapers[idx])

	case "restore":
		data, err := os.ReadFile(lastWallpaperFile)
		if err != nil {
			fmt.Println(ui.Warning("No hay wallpaper anterior guardado"))
			return
		}
		setWallpaper(strings.TrimSpace(string(data)))

	default:
		// Si es un path, establecerlo directamente
		setWallpaper(action)
	}
}

// ============ HOTKEY ============

func runHotkey(cmd *cobra.Command, args []string) {
	logger.Init("hotkey")
	defer logger.Close()

	homeDir, _ := os.UserHomeDir()
	configFile := filepath.Join(homeDir, ".config", "i3", "config")

	data, err := os.ReadFile(configFile)
	if err != nil {
		fmt.Println(ui.Error("No se pudo leer la configuración de i3"))
		return
	}

	fmt.Println(ui.Title("Atajos de Teclado i3"))
	fmt.Println()

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "bindsym") {
			parts := strings.SplitN(line, " ", 3)
			if len(parts) >= 3 {
				key := parts[1]
				action := parts[2]
				// Formatear para mejor lectura
				key = strings.ReplaceAll(key, "$mod", "Super")
				key = strings.ReplaceAll(key, "+", " + ")
				fmt.Printf("  %s → %s\n", ui.Highlight(key), action)
			}
		}
	}
}

// ============ MONITOR WATCHER ============

func runMonitorWatcher(cmd *cobra.Command, args []string) {
	logger.Init("monitor-watcher")
	defer logger.Close()

	fmt.Println(ui.Info("Monitoreando cambios de monitores..."))
	fmt.Println(ui.Dim("Presiona Ctrl+C para detener"))

	lastCount := 0
	for {
		output, _ := exec.Command("xrandr", "--query").Output()
		count := strings.Count(string(output), " connected")

		if count != lastCount && lastCount != 0 {
			fmt.Printf("📺 Cambio detectado: %d monitores\n", count)
			exec.Command("notify-send", "Monitores", fmt.Sprintf("Detectados %d monitores", count)).Run()
			
			// Mostrar menú con rofi
			options := "Duplicar\nDerecha\nIzquierda\nArriba\nAbajo"
			cmd := exec.Command("rofi", "-dmenu", "-i", "-p", "Monitor Setup", "-theme-str", "window {width: 30%;}")
			cmd.Stdin = strings.NewReader(options)
			choice, _ := cmd.Output()
			
			choiceStr := strings.TrimSpace(string(choice))
			if choiceStr != "" {
				fmt.Printf("Seleccionado: %s\n", choiceStr)
				// Aplicar configuración según selección
				applyMonitorConfig(choiceStr)
			}
		}
		lastCount = count
		time.Sleep(2 * time.Second)
	}
}

func applyMonitorConfig(choice string) {
	output, _ := exec.Command("xrandr", "--query").Output()
	lines := strings.Split(string(output), "\n")
	
	var displays []string
	for _, line := range lines {
		if strings.Contains(line, " connected") {
			parts := strings.Split(line, " ")
			displays = append(displays, parts[0])
		}
	}

	if len(displays) < 2 {
		fmt.Println(ui.Warning("Se necesitan al menos 2 monitores"))
		return
	}

	primary := displays[0]
	secondary := displays[1]

	var cmdArgs []string
	switch choice {
	case "Duplicar":
		cmdArgs = []string{"--output", primary, "--auto", "--primary", "--output", secondary, "--same-as", primary}
	case "Derecha":
		cmdArgs = []string{"--output", primary, "--auto", "--primary", "--output", secondary, "--auto", "--right-of", primary}
	case "Izquierda":
		cmdArgs = []string{"--output", primary, "--auto", "--primary", "--output", secondary, "--auto", "--left-of", primary}
	case "Arriba":
		cmdArgs = []string{"--output", primary, "--auto", "--primary", "--output", secondary, "--auto", "--above", primary}
	case "Abajo":
		cmdArgs = []string{"--output", primary, "--auto", "--primary", "--output", secondary, "--auto", "--below", primary}
	}

	if len(cmdArgs) > 0 {
		exec.Command("xrandr", cmdArgs...).Run()
		exec.Command("polybar-msg", "cmd", "restart").Run()
	}
}

// ============ PARU UPDATES ============

func runParuUpdates(cmd *cobra.Command, args []string) {
	if len(args) > 0 && args[0] == "update" {
		// Actualizar paquetes
		terminal := getTerminal()
		if terminal != "" {
			exec.Command(terminal, "-e", "bash", "-c", "echo 'Actualizando paquetes con paru...'; paru --noconfirm; echo 'Completado. Presiona Enter.'; read").Run()
		} else {
			exec.Command("paru", "--noconfirm").Run()
		}
		return
	}

	// Mostrar número de actualizaciones
	output, err := exec.Command("paru", "-Qu").Output()
	if err != nil {
		fmt.Println("0")
		return
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	count := 0
	for _, line := range lines {
		if line != "" {
			count++
		}
	}

	if count > 0 {
		fmt.Printf(" %d\n", count)
	} else {
		fmt.Println("")
	}
}

// ============ FLATPAK UPDATES ============

func runFlatpakUpdates(cmd *cobra.Command, args []string) {
	if len(args) > 0 && args[0] == "update" {
		// Actualizar flatpak
		terminal := getTerminal()
		if terminal != "" {
			exec.Command(terminal, "-e", "bash", "-c", "echo 'Actualizando Flatpak...'; flatpak update -y; echo 'Completado. Presiona Enter.'; read").Run()
		} else {
			exec.Command("flatpak", "update", "-y").Run()
		}
		return
	}

	// Mostrar número de actualizaciones
	output, err := exec.Command("flatpak", "remote-ls", "--updates").Output()
	if err != nil {
		fmt.Println("0")
		return
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	count := 0
	for _, line := range lines {
		if line != "" {
			count++
		}
	}

	if count > 0 {
		fmt.Printf(" %d\n", count)
	} else {
		fmt.Println("")
	}
}

// ============ POWER MENU ============

func runPowerMenu(cmd *cobra.Command, args []string) {
	logger.Init("powermenu")
	defer logger.Close()

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
	// Leer /proc/meminfo
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
				total = val / 1024 / 1024 // Convert to GB
			}
		} else if strings.HasPrefix(line, "MemAvailable:") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				val, _ := strconv.ParseFloat(parts[1], 64)
				available = val / 1024 / 1024 // Convert to GB
			}
		}
	}

	used := total - available
	fmt.Printf(" %.1fG\n", used)
}

// ============ KEYBOARD TOGGLE ============

func runKeyboardToggle(cmd *cobra.Command, args []string) {
	logger.Init("keyboard-toggle")
	defer logger.Close()

	// Obtener layout actual
	output, _ := exec.Command("setxkbmap", "-query").Output()
	lines := strings.Split(string(output), "\n")
	
	currentLayout := "us"
	for _, line := range lines {
		if strings.HasPrefix(line, "layout:") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				currentLayout = parts[1]
			}
		}
	}

	// Toggle entre us y es
	newLayout := "us"
	if currentLayout == "us" {
		newLayout = "es"
	}

	exec.Command("setxkbmap", newLayout).Run()
	exec.Command("notify-send", "-u", "low", "Teclado", fmt.Sprintf("Layout cambiado a %s", strings.ToUpper(newLayout))).Run()
	fmt.Printf("⌨️ Layout: %s\n", strings.ToUpper(newLayout))
}

// ============ HELPERS ============

func getTerminal() string {
	terminals := []string{"kitty", "alacritty", "gnome-terminal", "xterm"}
	for _, t := range terminals {
		if exec.Command("which", t).Run() == nil {
			return t
		}
	}
	return ""
}
