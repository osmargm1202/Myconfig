package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var webappCmd = &cobra.Command{
	Use:   "webapp",
	Short: "WebApp Creator",
	Long:  `Crea aplicaciones web como apps de escritorio.`,
	Run:   runWebapp,
}

func init() {
	rootCmd.AddCommand(webappCmd)

	webappCmd.AddCommand(&cobra.Command{
		Use:   "install",
		Short: "Instalar WebApp Creator como aplicación",
		Run:   runWebappInstall,
	})
}

type webApp struct {
	Name        string `json:"name"`
	URL         string `json:"url"`
	Description string `json:"description"`
	Categories  string `json:"categories"`
	Icon        string `json:"icon"`
	Created     string `json:"created"`
}

func runWebapp(cmd *cobra.Command, args []string) {
	logger.InitOnError("webapp")

	if err := ensureWebappEnv(); err != nil {
		fmt.Println(ui.Error(err.Error()))
		return
	}

	for {
		var action string
		form := ui.NewForm(
			huh.NewGroup(
				huh.NewSelect[string]().
					Title("WebApp Creator").
					Options(
						huh.NewOption("Crear nueva WebApp", "create"),
						huh.NewOption("Listar y lanzar WebApps", "list"),
						huh.NewOption("Eliminar WebApp", "remove"),
						huh.NewOption("Salir", "exit"),
					).
					Value(&action),
			),
		)

		if err := form.Run(); err != nil || action == "exit" {
			return
		}

		switch action {
		case "create":
			createWebappFlow()
		case "list":
			listWebappsFlow()
		case "remove":
			removeWebappFlow()
		}
	}
}

func runWebappInstall(cmd *cobra.Command, args []string) {
	logger.InitOnError("webapp")

	fmt.Println(ui.Title("Instalar WebApp Creator"))

	homeDir, _ := os.UserHomeDir()
	applicationsDir := filepath.Join(homeDir, ".local", "share", "applications")
	os.MkdirAll(applicationsDir, 0755)

	iconPath := ensureWebappCreatorIcon()
	if iconPath == "" {
		iconPath = "applications-internet"
	}

	desktopContent := fmt.Sprintf(`[Desktop Entry]
Name=WebApp Creator
Comment=Crear aplicaciones web como apps de escritorio
Exec=orgmos webapp
Terminal=true
Type=Application
Icon=%s
Categories=Development;Utility;
Keywords=webapp;browser;chrome;
`, iconPath)

	desktopPath := filepath.Join(applicationsDir, "webapp-creator.desktop")
	if err := os.WriteFile(desktopPath, []byte(desktopContent), 0o755); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
		logger.Error("Error creando desktop file: %v", err)
		return
	}

	repoDesktop := filepath.Join(utils.GetRepoDir(), "Apps", "webapp-creator.desktop")
	if err := os.MkdirAll(filepath.Dir(repoDesktop), 0o755); err == nil {
		_ = os.WriteFile(repoDesktop, []byte(desktopContent), 0o644)
	}

	fmt.Println(ui.Success("WebApp Creator instalado"))
	fmt.Println(ui.Info(fmt.Sprintf("Desktop file: %s", desktopPath)))
	logger.Info("WebApp Creator instalado")
}

func ensureWebappEnv() error {
	_, iconsDir, syncDir := webappPaths()
	if err := os.MkdirAll(iconsDir, 0o755); err != nil {
		return fmt.Errorf("no se pudo crear %s: %w", iconsDir, err)
	}
	if err := os.MkdirAll(syncDir, 0o755); err != nil {
		return fmt.Errorf("no se pudo crear %s: %w", syncDir, err)
	}
	configPath := filepath.Join(syncDir, "webapps.json")
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		if err := os.WriteFile(configPath, []byte("[]"), 0o644); err != nil {
			return fmt.Errorf("no se pudo crear %s: %w", configPath, err)
		}
	}
	return nil
}

func webappPaths() (appsDir, iconsDir, syncDir string) {
	homeDir, _ := os.UserHomeDir()
	appsDir = filepath.Join(homeDir, ".local", "share", "applications")
	iconsDir = filepath.Join(homeDir, ".local", "share", "icons", "webapp-icons")
	syncDir = filepath.Join(homeDir, ".local", "share", "webapp-sync")
	return
}

func loadWebapps() ([]webApp, error) {
	_, _, syncDir := webappPaths()
	data, err := os.ReadFile(filepath.Join(syncDir, "webapps.json"))
	if err != nil {
		return nil, err
	}
	var apps []webApp
	if err := json.Unmarshal(data, &apps); err != nil {
		return nil, err
	}
	return apps, nil
}

func saveWebapps(apps []webApp) error {
	_, _, syncDir := webappPaths()
	data, err := json.MarshalIndent(apps, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(syncDir, "webapps.json"), data, 0o644)
}

func createWebappFlow() {
	chromiumBin, ok := ensureChromium()
	if !ok {
		return
	}

	var name, url, description string
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Nombre de la WebApp").
				Placeholder("Ej: ChatGPT").
				Value(&name),
		),
		huh.NewGroup(
			huh.NewInput().
				Title("URL (https:// se agregará si falta)").
				Placeholder("https://chatgpt.com").
				Value(&url),
		),
		huh.NewGroup(
			huh.NewInput().
				Title("Descripción").
				Placeholder("Aplicación Web").
				Value(&description),
		),
	)

	if err := form.Run(); err != nil || strings.TrimSpace(name) == "" || strings.TrimSpace(url) == "" {
		return
	}

	if !strings.HasPrefix(strings.ToLower(url), "http") {
		url = "https://" + url
	}
	if description == "" {
		description = fmt.Sprintf("%s WebApp", name)
	}

	categories := selectWebappCategory()
	if categories == "" {
		return
	}

	iconSource := selectIconSource()
	if iconSource == "" {
		return
	}

	iconPath, err := copyIconForApp(name, iconSource)
	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("No se pudo preparar el icono: %v", err)))
		return
	}

	app := webApp{
		Name:        name,
		URL:         url,
		Description: description,
		Categories:  categories,
		Icon:        iconPath,
		Created:     time.Now().UTC().Format(time.RFC3339),
	}

	if err := createDesktopEntry(app, chromiumBin); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("No se pudo crear el .desktop: %v", err)))
		return
	}

	apps, err := loadWebapps()
	if err != nil {
		fmt.Println(ui.Error("No se pudo leer la configuración"))
		return
	}

	apps = appendOrReplaceWebapp(apps, app)
	if err := saveWebapps(apps); err != nil {
		fmt.Println(ui.Error("No se pudo guardar la configuración"))
		return
	}

	fmt.Println(ui.Success(fmt.Sprintf("WebApp '%s' creada", name)))
}

func selectWebappCategory() string {
	options := []huh.Option[string]{
		huh.NewOption("AudioVideo (Media)", "AudioVideo;"),
		huh.NewOption("Development (Herramientas)", "Development;"),
		huh.NewOption("Education", "Education;"),
		huh.NewOption("Game", "Game;"),
		huh.NewOption("Graphics", "Graphics;"),
		huh.NewOption("Network / Web", "Network;WebBrowser;"),
		huh.NewOption("Office / Productividad", "Office;"),
		huh.NewOption("Science", "Science;"),
		huh.NewOption("System", "System;"),
		huh.NewOption("Utility", "Utility;"),
		huh.NewOption("Personalizado", "custom"),
	}

	var selected string
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title("Categoría de la aplicación").
				Options(options...).
				Value(&selected),
		),
	)

	if err := form.Run(); err != nil || selected == "" {
		return ""
	}

	if selected != "custom" {
		return selected
	}

	var custom string
	customForm := ui.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Categorías personalizadas (separadas por ;)").
				Placeholder("Network;WebBrowser;").
				Value(&custom),
		),
	)
	if err := customForm.Run(); err != nil || strings.TrimSpace(custom) == "" {
		return ""
	}
	return custom
}

func selectIconSource() string {
	repoIcons := listRepoIcons()
	options := make([]huh.Option[string], 0, len(repoIcons)+1)
	for _, icon := range repoIcons {
		options = append(options, huh.NewOption(icon.DisplayName, icon.Path))
	}
	options = append(options, huh.NewOption("Seleccionar archivo personalizado", "custom"))

	var selected string
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title("Selecciona un icono").
				Options(options...).
				Value(&selected),
		),
	)
	if err := form.Run(); err != nil || selected == "" {
		return ""
	}

	if selected != "custom" {
		return selected
	}

	var path string
	customForm := ui.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Ruta del icono (.png)").
				Placeholder("/ruta/a/icono.png").
				Value(&path),
		),
	)
	if err := customForm.Run(); err != nil || strings.TrimSpace(path) == "" {
		return ""
	}

	return path
}

type repoIcon struct {
	DisplayName string
	Path        string
}

func listRepoIcons() []repoIcon {
	var icons []repoIcon
	repoDir := utils.GetRepoDir()
	iconDir := filepath.Join(repoDir, "Icons", "webapp-icons")
	entries, err := os.ReadDir(iconDir)
	if err != nil {
		return icons
	}
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(strings.ToLower(entry.Name()), ".png") {
			continue
		}
		name := strings.TrimSuffix(entry.Name(), filepath.Ext(entry.Name()))
		icons = append(icons, repoIcon{
			DisplayName: name,
			Path:        filepath.Join(iconDir, entry.Name()),
		})
	}
	return icons
}

func copyIconForApp(appName, source string) (string, error) {
	_, iconsDir, _ := webappPaths()
	target := filepath.Join(iconsDir, sanitizeFileName(appName)+".png")

	srcFile, err := os.Open(source)
	if err != nil {
		return "", err
	}
	defer srcFile.Close()

	err = func() error {
		dst, err := os.Create(target)
		if err != nil {
			return err
		}
		defer dst.Close()
		_, err = io.Copy(dst, srcFile)
		return err
	}()
	if err != nil {
		return "", err
	}
	return target, nil
}

func sanitizeFileName(name string) string {
	normalized := strings.ToLower(strings.TrimSpace(name))
	normalized = strings.ReplaceAll(normalized, " ", "-")
	normalized = strings.ReplaceAll(normalized, "/", "-")
	return normalized
}

func ensureChromium() (string, bool) {
	candidates := []string{"chromium", "chromium-browser"}
	for _, c := range candidates {
		if utils.CommandExists(c) {
			return c, true
		}
	}

	var install bool
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title("Chromium no está instalado").
				Description("¿Deseas instalar Chromium ahora?").
				Affirmative("Instalar").
				Negative("Cancelar").
				Value(&install),
		),
	)

	if err := form.Run(); err != nil || !install {
		fmt.Println(ui.Warning("WebApp Creator necesita Chromium"))
		return "", false
	}

	if err := utils.RunCommand("sudo", "pacman", "-S", "--needed", "chromium"); err != nil {
		fmt.Println(ui.Error("No se pudo instalar Chromium automáticamente"))
		return "", false
	}

	if utils.CommandExists("chromium") {
		return "chromium", true
	}
	if utils.CommandExists("chromium-browser") {
		return "chromium-browser", true
	}
	fmt.Println(ui.Error("Chromium sigue sin estar disponible"))
	return "", false
}

func createDesktopEntry(app webApp, chromium string) error {
	appsDir, _, _ := webappPaths()
	if err := os.MkdirAll(appsDir, 0o755); err != nil {
		return err
	}

	desktopPath := filepath.Join(appsDir, sanitizeFileName(app.Name)+".desktop")
	content := fmt.Sprintf(`[Desktop Entry]
Version=1.0
Type=Application
Name=%s
Comment=%s
Exec=%s --app="%s" --new-window --class="%s"
Icon=%s
Categories=%s
NoDisplay=false
StartupWMClass=%s
StartupNotify=true
Terminal=false
`, app.Name, app.Description, chromium, app.URL, app.Name, app.Icon, app.Categories, app.Name)

	return os.WriteFile(desktopPath, []byte(content), 0o755)
}

func appendOrReplaceWebapp(apps []webApp, app webApp) []webApp {
	for i, existing := range apps {
		if strings.EqualFold(existing.Name, app.Name) {
			apps[i] = app
			return apps
		}
	}
	return append(apps, app)
}

func listWebappsFlow() {
	apps, err := loadWebapps()
	if err != nil || len(apps) == 0 {
		fmt.Println(ui.Warning("No hay WebApps registradas"))
		return
	}

	options := make([]huh.Option[string], 0, len(apps))
	for _, app := range apps {
		label := fmt.Sprintf("%s (%s)", app.Name, app.URL)
		options = append(options, huh.NewOption(label, app.Name))
	}

	var selected string
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title("Selecciona una WebApp para lanzar").
				Options(options...).
				Value(&selected),
		),
	)

	if err := form.Run(); err != nil || selected == "" {
		return
	}

	for _, app := range apps {
		if app.Name == selected {
			launchWebapp(app)
			return
		}
	}
}

func launchWebapp(app webApp) {
	chromium, ok := ensureChromium()
	if !ok {
		return
	}

	cmd := exec.Command(chromium, "--app="+app.URL, "--new-window", "--class="+app.Name)
	if err := cmd.Start(); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("No se pudo lanzar %s: %v", app.Name, err)))
		return
	}
	fmt.Println(ui.Success(fmt.Sprintf("Lanzando %s...", app.Name)))
}

func removeWebappFlow() {
	apps, err := loadWebapps()
	if err != nil || len(apps) == 0 {
		fmt.Println(ui.Warning("No hay WebApps registradas"))
		return
	}

	options := make([]huh.Option[string], 0, len(apps))
	for _, app := range apps {
		options = append(options, huh.NewOption(app.Name, app.Name))
	}

	var selected string
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title("Selecciona la WebApp a eliminar").
				Options(options...).
				Value(&selected),
		),
	)

	if err := form.Run(); err != nil || selected == "" {
		return
	}

	var confirm bool
	confirmForm := ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title(fmt.Sprintf("Eliminar '%s'?", selected)).
				Affirmative("Eliminar").
				Negative("Cancelar").
				Value(&confirm),
		),
	)

	if err := confirmForm.Run(); err != nil || !confirm {
		return
	}

	var updated []webApp
	for _, app := range apps {
		if app.Name == selected {
			removeDesktopAndIcon(app)
			continue
		}
		updated = append(updated, app)
	}

	if err := saveWebapps(updated); err != nil {
		fmt.Println(ui.Error("No se pudo actualizar la configuración"))
		return
	}

	fmt.Println(ui.Success(fmt.Sprintf("WebApp '%s' eliminada", selected)))
}

func removeDesktopAndIcon(app webApp) {
	appsDir, _, _ := webappPaths()
	os.Remove(filepath.Join(appsDir, sanitizeFileName(app.Name)+".desktop"))
	if app.Icon != "" {
		os.Remove(app.Icon)
	}
}

func ensureWebappCreatorIcon() string {
	repoDir := utils.GetRepoDir()
	source := filepath.Join(repoDir, "Icons", "webapp-icons", "webapp-creator.png")
	if _, err := os.Stat(source); err != nil {
		return ""
	}

	_, iconsDir, _ := webappPaths()
	os.MkdirAll(iconsDir, 0o755)
	target := filepath.Join(iconsDir, "webapp-creator.png")
	src, err := os.Open(source)
	if err != nil {
		return ""
	}
	defer src.Close()

	if dst, err := os.Create(target); err == nil {
		defer dst.Close()
		if _, err := io.Copy(dst, src); err == nil {
			return target
		}
	}

	return ""
}

