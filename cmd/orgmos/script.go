package main

import (
	"bufio"
	"encoding/json"
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

type windowManager string

const (
	wmI3        windowManager = "i3"
	wmHyprland  windowManager = "hyprland"
	wmNiri      windowManager = "niri"
	wmUnknown   windowManager = "unknown"
	stateFolder               = "orgmos"
)

type hyprGameModeState struct {
	Enabled          bool `json:"enabled"`
	StoppedHypridle  bool `json:"stoppedHypridle"`
}

type niriGameModeState struct {
	Enabled     bool     `json:"enabled"`
	SwayidleCmd []string `json:"swayidle_cmd"`
}

type caffeineWaylandState struct {
	Enabled   bool `json:"enabled"`
	InhibitPID int  `json:"inhibit_pid"`
}

func detectWindowManager() windowManager {
	if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") != "" || processExists("Hyprland", "hyprland") {
		return wmHyprland
	}

	if processExists("niri") {
		return wmNiri
	}

	if processExists("i3") || strings.Contains(strings.ToLower(os.Getenv("DESKTOP_SESSION")), "i3") {
		return wmI3
	}

	if os.Getenv("WAYLAND_DISPLAY") != "" {
		if utils.CommandExists("niri") {
			return wmNiri
		}
		if utils.CommandExists("hyprctl") {
			return wmHyprland
		}
	}

	if utils.CommandExists("i3-msg") {
		return wmI3
	}

	return wmI3
}

func processExists(names ...string) bool {
	for _, name := range names {
		if name == "" {
			continue
		}
		if exec.Command("pgrep", "-x", name).Run() == nil {
			return true
		}
	}
	return false
}

func orgmosStatePath(filename string) string {
	homeDir, _ := os.UserHomeDir()
	dir := filepath.Join(homeDir, ".config", stateFolder)
	os.MkdirAll(dir, 0o755)
	return filepath.Join(dir, filename)
}

func readJSONState(path string, target any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, target)
}

func writeJSONState(path string, value any) error {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o644)
}

// ============ CAFFEINE ============

func runCaffeine(cmd *cobra.Command, args []string) {
	logger.Init("caffeine")
	defer logger.Close()

	action := "toggle"
	if len(args) > 0 {
		action = args[0]
	}

	wm := detectWindowManager()
	switch wm {
	case wmHyprland, wmNiri:
		runCaffeineWayland(wm, action)
	default:
		runCaffeineI3(action)
	}
}

func runCaffeineI3(action string) {
	homeDir, _ := os.UserHomeDir()
	stateFile := filepath.Join(homeDir, ".config", "i3", "caffeine_state")

	getState := func() string {
		data, err := os.ReadFile(stateFile)
		if err != nil {
			return "enabled"
		}
		return strings.TrimSpace(string(data))
	}

	setState := func(state string) {
		os.MkdirAll(filepath.Dir(stateFile), 0o755)
		os.WriteFile(stateFile, []byte(state), 0o644)
	}

	enableCaffeine := func() {
		utils.RunCommand("xset", "-dpms")
		utils.RunCommand("xset", "s", "off")
		utils.RunCommand("pkill", "-x", "xss-lock")
		utils.RunCommand("pkill", "-x", "xautolock")
		setState("enabled")
		utils.RunCommand("polybar-msg", "hook", "caffeine", "1")
		utils.RunCommand("notify-send", "Cafeína", "Modo cafeína activado")
		fmt.Println("☕ Modo cafeína activado (i3)")
	}

	disableCaffeine := func() {
		utils.RunCommand("xset", "+dpms")
		utils.RunCommand("xset", "s", "300", "5")
		utils.RunCommand("xset", "dpms", "600", "1200", "1800")

		if exec.Command("pgrep", "-x", "xautolock").Run() != nil {
			exec.Command("xautolock", "-time", "5", "-locker", "i3lock --blur 5", "-detectsleep").Start()
		}

		if exec.Command("pgrep", "-x", "xss-lock").Run() != nil {
			exec.Command("xss-lock", "--transfer-sleep-lock", "--", "i3lock", "--blur", "5").Start()
		}

		setState("disabled")
		utils.RunCommand("polybar-msg", "hook", "caffeine", "1")
		utils.RunCommand("notify-send", "Cafeína", "Modo cafeína desactivado")
		fmt.Println("💤 Modo cafeína desactivado (i3)")
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

func runCaffeineWayland(wm windowManager, action string) {
	statePath := orgmosStatePath(fmt.Sprintf("caffeine_%s.json", wm))
	state := caffeineWaylandState{}
	_ = readJSONState(statePath, &state)

	enable := func() {
		if state.Enabled {
			fmt.Println(ui.Info("Cafeína ya estaba activa"))
			return
		}

		cmd := exec.Command(
			"systemd-inhibit",
			"--what=idle:sleep",
			"--why", fmt.Sprintf("orgmos caffeine (%s)", wm),
			"bash", "-c", "while true; do sleep 300; done",
		)
		if err := cmd.Start(); err != nil {
			fmt.Println(ui.Error("No se pudo crear la inhibición de energía"))
			return
		}

		state.Enabled = true
		state.InhibitPID = cmd.Process.Pid
		writeJSONState(statePath, state)
		fmt.Println("☕ Modo cafeína activado (Wayland)")
		utils.RunCommand("notify-send", "Cafeína", fmt.Sprintf("Modo cafeína activo en %s", strings.ToUpper(string(wm))))
	}

	disable := func() {
		if !state.Enabled {
			fmt.Println(ui.Info("Cafeína ya estaba desactivada"))
			return
		}

		if state.InhibitPID != 0 {
			if proc, err := os.FindProcess(state.InhibitPID); err == nil {
				proc.Kill()
			}
		}
		state.Enabled = false
		state.InhibitPID = 0
		writeJSONState(statePath, state)
		fmt.Println("💤 Modo cafeína desactivado (Wayland)")
		utils.RunCommand("notify-send", "Cafeína", fmt.Sprintf("Modo cafeína desactivado en %s", strings.ToUpper(string(wm))))
	}

	switch action {
	case "toggle":
		if state.Enabled {
			disable()
		} else {
			enable()
		}
	case "enable":
		enable()
	case "disable":
		disable()
	case "status":
		if state.Enabled {
			fmt.Println("enabled")
		} else {
			fmt.Println("disabled")
		}
	default:
		fmt.Println("Uso: orgmos script caffeine [toggle|enable|disable|status]")
	}
}

// ============ GAME MODE ============

func runGameMode(cmd *cobra.Command, args []string) {
	logger.Init("game-mode")
	defer logger.Close()

	wm := detectWindowManager()
	fmt.Println(ui.Info(fmt.Sprintf("Window Manager detectado: %s", strings.ToUpper(string(wm)))))

	switch wm {
	case wmHyprland:
		runGameModeHyprland(args)
	case wmNiri:
		runGameModeNiri(args)
	case wmI3, wmUnknown:
		fallthrough
	default:
		runGameModeI3(args)
	}
}

func runGameModeI3(args []string) {
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
		fmt.Println("🎮 Aplicando optimizaciones para juegos (i3)...")
		exec.Command("sudo", "cpupower", "frequency-set", "-g", "performance").Run()
	}

	revertOptimizations := func() {
		fmt.Println("🔄 Revirtiendo optimizaciones (i3)...")
		exec.Command("sudo", "cpupower", "frequency-set", "-g", "ondemand").Run()
	}

	if len(args) > 0 && args[0] == "reload" {
		fmt.Println("🔄 Reiniciando picom/polybar...")
		stopProcess("picom")
		stopProcess("polybar")
		startPicom()
		startPolybar()
		exec.Command("notify-send", "Modo Juego i3", "Servicios reiniciados").Run()
		return
	}

	picomRunning := isRunning("picom")
	polybarRunning := isRunning("polybar")

	if picomRunning && polybarRunning {
		fmt.Println("🎮 ACTIVANDO MODO JUEGO (i3)...")
		stopProcess("picom")
		stopProcess("polybar")
		applyOptimizations()
		exec.Command("notify-send", "Modo Juego i3", "Activado 🎮").Run()
	} else if !picomRunning && !polybarRunning {
		fmt.Println("🖥️  DESACTIVANDO MODO JUEGO (i3)...")
		revertOptimizations()
		startPicom()
		startPolybar()
		exec.Command("notify-send", "Modo Juego i3", "Desactivado 🖥️").Run()
	} else {
		fmt.Println("⚖️  Normalizando estado de servicios (i3)...")
		if !picomRunning {
			startPicom()
		}
		if !polybarRunning {
			startPolybar()
		}
		revertOptimizations()
		exec.Command("notify-send", "Modo Juego i3", "Servicios sincronizados").Run()
	}

	fmt.Printf("\nEstado final:\n")
	fmt.Printf("  Picom: %s\n", map[bool]string{true: "🟢 Activo", false: "🔴 Inactivo"}[isRunning("picom")])
	fmt.Printf("  Polybar: %s\n", map[bool]string{true: "🟢 Activo", false: "🔴 Inactivo"}[isRunning("polybar")])
}

func runGameModeHyprland(args []string) {
	statePath := orgmosStatePath("game_mode_hyprland.json")
	state := hyprGameModeState{}
	_ = readJSONState(statePath, &state)

	if len(args) > 0 && args[0] == "reload" {
		fmt.Println(ui.Info("Recargando configuración de Hyprland..."))
		utils.RunCommand("hyprctl", "reload")
		return
	}

	if state.Enabled {
		fmt.Println(ui.Info("Desactivando modo juego para Hyprland"))
		utils.RunCommand("hyprctl", "reload")
		if state.StoppedHypridle {
			fmt.Println(ui.Info("Reiniciando hypridle"))
			exec.Command("hypridle").Start()
		}
		state.Enabled = false
		state.StoppedHypridle = false
		writeJSONState(statePath, state)
		exec.Command("notify-send", "Modo Juego Hyprland", "Desactivado 🖥️").Run()
		return
	}

	fmt.Println(ui.Info("Activando modo juego para Hyprland (deshabilitando animaciones y efectos)"))
	commands := [][]string{
		{"keyword", "animations:enabled", "0"},
		{"keyword", "decoration:drop_shadow", "false"},
		{"keyword", "decoration:blur:enabled", "false"},
	}

	for _, args := range commands {
		utils.RunCommand("hyprctl", args...)
	}

	stoppedHypridle := false
	if processExists("hypridle") {
		fmt.Println(ui.Info("Deteniendo hypridle para evitar bloqueos"))
		exec.Command("pkill", "-x", "hypridle").Run()
		stoppedHypridle = true
	}

	state.Enabled = true
	state.StoppedHypridle = stoppedHypridle
	writeJSONState(statePath, state)
	exec.Command("notify-send", "Modo Juego Hyprland", "Activado 🎮").Run()
}

func runGameModeNiri(args []string) {
	statePath := orgmosStatePath("game_mode_niri.json")
	state := niriGameModeState{}
	_ = readJSONState(statePath, &state)

	if len(args) > 0 && args[0] == "reload" {
		fmt.Println(ui.Info("Recargando configuración de Niri..."))
		utils.RunCommand("niri", "msg", "action", "reload-config")
		return
	}

	if state.Enabled {
		fmt.Println(ui.Info("Desactivando modo juego para Niri"))
		if len(state.SwayidleCmd) > 0 {
			cmd := exec.Command(state.SwayidleCmd[0], state.SwayidleCmd[1:]...)
			cmd.Start()
			fmt.Println(ui.Info("swayidle restaurado"))
		}
		utils.RunCommand("niri", "msg", "action", "reload-config")
		state.Enabled = false
		state.SwayidleCmd = nil
		writeJSONState(statePath, state)
		exec.Command("notify-send", "Modo Juego Niri", "Desactivado 🖥️").Run()
		return
	}

	fmt.Println(ui.Info("Activando modo juego para Niri (deteniendo swayidle)"))
	if processExists("swayidle") {
		if cmdline := captureProcessCmdline("swayidle"); len(cmdline) > 0 {
			state.SwayidleCmd = cmdline
			exec.Command("pkill", "-x", "swayidle").Run()
		}
	}

	state.Enabled = true
	writeJSONState(statePath, state)
	exec.Command("notify-send", "Modo Juego Niri", "Activado 🎮").Run()
}

// ============ LOCK ============

func runLock(cmd *cobra.Command, args []string) {
	logger.Init("lock")
	defer logger.Close()

	wm := detectWindowManager()
	if caffeineActive(wm) {
		fmt.Println(ui.Warning("Cafeína está activada, no se bloqueará la pantalla"))
		return
	}

	switch wm {
	case wmHyprland, wmNiri:
		lockWayland(wm)
	default:
		lockI3()
	}
}

func caffeineActive(wm windowManager) bool {
	switch wm {
	case wmHyprland, wmNiri:
		state := caffeineWaylandState{}
		statePath := orgmosStatePath(fmt.Sprintf("caffeine_%s.json", wm))
		if err := readJSONState(statePath, &state); err != nil {
			return false
		}
		return state.Enabled
	default:
		homeDir, _ := os.UserHomeDir()
		stateFile := filepath.Join(homeDir, ".config", "i3", "caffeine_state")
		if data, err := os.ReadFile(stateFile); err == nil {
			return strings.TrimSpace(string(data)) == "enabled"
		}
		return false
	}
}

func lockI3() {
	exec.Command("i3lock", "--blur", "5", "--clock", "--date-str", "%A, %B %d", "--time-str", "%I:%M %p").Run()
}

func lockWayland(wm windowManager) {
	candidates := [][]string{}
	if utils.CommandExists("hyprlock") {
		candidates = append(candidates, []string{"hyprlock"})
	}
	if utils.CommandExists("swaylock") {
		candidates = append(candidates, []string{"swaylock"})
	}
	if utils.CommandExists("gtklock") {
		candidates = append(candidates, []string{"gtklock"})
	}

	for _, candidate := range candidates {
		if err := exec.Command(candidate[0], candidate[1:]...).Run(); err == nil {
			return
		}
	}

	fmt.Println(ui.Warning("No se encontró un locker específico, usando loginctl"))
	utils.RunCommand("loginctl", "lock-session")
}

// ============ CHANGE WALLPAPER ============

func runChangeWallpaper(cmd *cobra.Command, args []string) {
	logger.Init("change-wallpaper")
	defer logger.Close()

	homeDir, _ := os.UserHomeDir()
	wm := detectWindowManager()

	lastWallpaperFile := filepath.Join(homeDir, ".config", "i3", "last_wallpaper")
	if wm != wmI3 {
		lastWallpaperFile = orgmosStatePath(fmt.Sprintf("last_wallpaper_%s", wm))
	}

	picturesDir := filepath.Join(homeDir, "Pictures", "Wallpapers")
	repoDir := utils.GetRepoDir()
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
	if len(args) > 0 {
		action = args[0]
	}

	setWallpaper := func(path string) {
		if _, err := os.Stat(path); err != nil {
			fmt.Println(ui.Error("Wallpaper no encontrado: " + path))
			return
		}
		if err := applyWallpaperForWM(wm, path); err != nil {
			fmt.Println(ui.Error(fmt.Sprintf("No se pudo aplicar el wallpaper: %v", err)))
			return
		}
		os.WriteFile(lastWallpaperFile, []byte(path), 0o644)
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

	wm := detectWindowManager()
	switch wm {
	case wmHyprland:
		showHyprlandHotkeys()
	case wmNiri:
		showNiriHotkeys()
	default:
		showI3Hotkeys()
	}
}

func showI3Hotkeys() {
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

func showHyprlandHotkeys() {
	homeDir, _ := os.UserHomeDir()
	paths := []string{
		filepath.Join(homeDir, ".config", "hypr", "keybindings.conf"),
		filepath.Join(utils.GetRepoDir(), "configs_to_copy", "hypr", "keybindings.conf"),
	}

	var data []byte
	for _, path := range paths {
		if content, err := os.ReadFile(path); err == nil {
			data = content
			break
		}
	}

	if len(data) == 0 {
		fmt.Println(ui.Error("No se encontró keybindings.conf de Hyprland"))
		return
	}

	fmt.Println(ui.Title("Atajos de Teclado Hyprland"))
	fmt.Println()

	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "bind") {
			parts := strings.SplitN(line, "=", 2)
			if len(parts) < 2 {
				continue
			}
			values := strings.Split(parts[1], ",")
			if len(values) < 3 {
				continue
			}
			mod := strings.TrimSpace(values[0])
			key := strings.TrimSpace(values[1])
			desc := strings.TrimSpace(values[2])
			mod = strings.ReplaceAll(mod, "$mainMod", "Super")
			shortcut := strings.TrimSpace(fmt.Sprintf("%s + %s", mod, key))
			fmt.Printf("  %s → %s\n", ui.Highlight(shortcut), desc)
		}
	}
}

func showNiriHotkeys() {
	homeDir, _ := os.UserHomeDir()
	paths := []string{
		filepath.Join(homeDir, ".config", "niri", "config.kdl"),
		filepath.Join(utils.GetRepoDir(), "configs_to_copy", "niri", "config.kdl"),
	}

	var data []byte
	for _, path := range paths {
		if content, err := os.ReadFile(path); err == nil {
			data = content
			break
		}
	}

	if len(data) == 0 {
		fmt.Println(ui.Error("No se encontró config.kdl de Niri"))
		return
	}

	fmt.Println(ui.Title("Atajos de Teclado Niri"))
	fmt.Println()

	inBinds := false
	depth := 0
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "//") {
			continue
		}
		if strings.HasPrefix(line, "binds") && strings.HasSuffix(line, "{") {
			inBinds = true
			depth = 1
			continue
		}
		if !inBinds {
			continue
		}

		depth += strings.Count(line, "{")
		depth -= strings.Count(line, "}")
		if depth <= 0 {
			inBinds = false
			continue
		}

		if !strings.Contains(line, "{") {
			continue
		}

		parts := strings.SplitN(line, "{", 2)
		key := strings.TrimSpace(parts[0])
		action := strings.TrimSpace(parts[1])
		action = strings.TrimSuffix(action, "}")
		fmt.Printf("  %s → %s\n", ui.Highlight(key), action)
	}
}

// ============ MONITOR WATCHER ============

func runMonitorWatcher(cmd *cobra.Command, args []string) {
	logger.Init("monitor-watcher")
	defer logger.Close()

	wm := detectWindowManager()
	fmt.Println(ui.Info(fmt.Sprintf("Monitoreando cambios de monitores (%s)...", strings.ToUpper(string(wm)))))
	fmt.Println(ui.Dim("Presiona Ctrl+C para detener"))

	switch wm {
	case wmHyprland:
		runMonitorWatcherHyprland()
	case wmNiri:
		runMonitorWatcherNiri()
	default:
		runMonitorWatcherX11()
	}
}

func runMonitorWatcherX11() {
	lastCount := 0
	for {
		output, _ := exec.Command("xrandr", "--query").Output()
		count := strings.Count(string(output), " connected")

		if count != lastCount && lastCount != 0 {
			fmt.Printf("📺 Cambio detectado: %d monitores\n", count)
			exec.Command("notify-send", "Monitores", fmt.Sprintf("Detectados %d monitores", count)).Run()

			options := "Duplicar\nDerecha\nIzquierda\nArriba\nAbajo"
			cmd := exec.Command("rofi", "-dmenu", "-i", "-p", "Monitor Setup", "-theme-str", "window {width: 30%;}")
			cmd.Stdin = strings.NewReader(options)
			choice, _ := cmd.Output()

			choiceStr := strings.TrimSpace(string(choice))
			if choiceStr != "" {
				fmt.Printf("Seleccionado: %s\n", choiceStr)
				applyMonitorConfig(choiceStr)
			}
		}
		lastCount = count
		time.Sleep(2 * time.Second)
	}
}

func runMonitorWatcherHyprland() {
	lastSnapshot := ""
	for {
		output, err := exec.Command("hyprctl", "monitors", "-j").Output()
		if err != nil {
			fmt.Println(ui.Error("No se pudieron consultar los monitores de Hyprland"))
			time.Sleep(3 * time.Second)
			continue
		}

		current := string(output)
		if lastSnapshot != "" && current != lastSnapshot {
			fmt.Println(ui.Success("Cambio de monitores detectado en Hyprland, aplicando hyprctl reload"))
			utils.RunCommand("hyprctl", "reload")
			exec.Command("notify-send", "Hyprland", "Monitores reconfigurados").Run()
		}
		lastSnapshot = current
		time.Sleep(2 * time.Second)
	}
}

func runMonitorWatcherNiri() {
	lastSnapshot := ""
	for {
		output, err := exec.Command("niri", "msg", "outputs").Output()
		if err != nil {
			fmt.Println(ui.Error("No se pudieron consultar los outputs de Niri"))
			time.Sleep(3 * time.Second)
			continue
		}

		current := string(output)
		if lastSnapshot != "" && current != lastSnapshot {
			fmt.Println(ui.Success("Cambio de monitores detectado en Niri, recargando configuración"))
			utils.RunCommand("niri", "msg", "action", "reload-config")
			exec.Command("notify-send", "Niri", "Monitores reconfigurados").Run()
		}
		lastSnapshot = current
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

func applyWallpaperForWM(wm windowManager, path string) error {
	switch wm {
	case wmHyprland:
		if err := setHyprlandWallpaper(path); err == nil {
			return nil
		}
		return setWaylandWallpaper(path)
	case wmNiri:
		return setWaylandWallpaper(path)
	default:
		return setXWallpaper(path)
	}
}

func setXWallpaper(path string) error {
	return exec.Command("xwallpaper", "--zoom", path).Run()
}

func setWaylandWallpaper(path string) error {
	exec.Command("pkill", "-x", "swaybg").Run()
	cmd := exec.Command("swaybg", "-i", path, "-m", "fill")
	return cmd.Start()
}

func setHyprlandWallpaper(path string) error {
	if !utils.CommandExists("hyprctl") {
		return fmt.Errorf("hyprctl no disponible")
	}

	utils.RunCommand("hyprctl", "hyprpaper", "preload", path)

	output, err := exec.Command("hyprctl", "monitors", "-j").Output()
	if err != nil {
		return err
	}

	var monitors []struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(output, &monitors); err != nil {
		return err
	}

	if len(monitors) == 0 {
		return fmt.Errorf("no se detectaron monitores en Hyprland")
	}

	for _, monitor := range monitors {
		utils.RunCommand("hyprctl", "hyprpaper", "wallpaper", fmt.Sprintf("%s,%s", monitor.Name, path))
	}
	return nil
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

func captureProcessCmdline(process string) []string {
	pids, err := exec.Command("pgrep", "-x", process).Output()
	if err != nil {
		return nil
	}

	fields := strings.Fields(string(pids))
	if len(fields) == 0 {
		return nil
	}

	cmdlinePath := filepath.Join("/proc", fields[0], "cmdline")
	data, err := os.ReadFile(cmdlinePath)
	if err != nil {
		return nil
	}

	raw := strings.Split(string(data), "\x00")
	var args []string
	for _, part := range raw {
		part = strings.TrimSpace(part)
		if part != "" {
			args = append(args, part)
		}
	}
	return args
}
