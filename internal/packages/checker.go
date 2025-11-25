package packages

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/charmbracelet/huh"

	"orgmos/internal/logger"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

// PackageStatus representa el estado de un paquete
type PackageStatus struct {
	Name      string
	Installed bool
	Source    string // "pacman", "aur", "multilib", "chaotic", "flatpak"
}

// CheckInstalledPacman verifica paquetes instalados con pacman
func CheckInstalledPacman(packages []string) map[string]bool {
	installed := make(map[string]bool)

	// Obtener lista de paquetes instalados
	output, err := utils.RunCommandSilent("pacman", "-Qq")
	if err != nil {
		logger.Error("Error obteniendo paquetes instalados: %v", err)
		return installed
	}

	installedPkgs := make(map[string]bool)
	for _, pkg := range strings.Split(output, "\n") {
		pkg = strings.TrimSpace(pkg)
		if pkg != "" {
			installedPkgs[pkg] = true
		}
	}

	for _, pkg := range packages {
		installed[pkg] = installedPkgs[pkg]
	}

	return installed
}

// CheckInstalledFlatpak verifica apps Flatpak instaladas
func CheckInstalledFlatpak(packages []string) map[string]bool {
	installed := make(map[string]bool)

	output, err := utils.RunCommandSilent("flatpak", "list", "--app", "--columns=application")
	if err != nil {
		logger.Error("Error obteniendo flatpaks: %v", err)
		return installed
	}

	installedApps := make(map[string]bool)
	for _, app := range strings.Split(output, "\n") {
		app = strings.TrimSpace(app)
		if app != "" {
			installedApps[app] = true
		}
	}

	for _, pkg := range packages {
		installed[pkg] = installedApps[pkg]
	}

	return installed
}

// GetPackageSource determina el origen de un paquete
func GetPackageSource(pkg string) string {
	// Verificar en repos oficiales
	output, err := utils.RunCommandSilent("pacman", "-Si", pkg)
	if err == nil {
		if strings.Contains(output, "Repository      : core") ||
			strings.Contains(output, "Repository      : extra") ||
			strings.Contains(output, "Repository      : community") {
			return "pacman"
		}
		if strings.Contains(output, "Repository      : multilib") {
			return "multilib"
		}
		if strings.Contains(output, "Repository      : chaotic-aur") {
			return "chaotic"
		}
	}

	// Verificar en AUR (paru o yay)
	if utils.CommandExists("paru") {
		_, err = utils.RunCommandSilent("paru", "-Si", pkg)
		if err == nil {
			return "aur"
		}
	} else if utils.CommandExists("yay") {
		_, err = utils.RunCommandSilent("yay", "-Si", pkg)
		if err == nil {
			return "aur"
		}
	}

	return "unknown"
}

// CategorizePackages separa paquetes por origen
func CategorizePackages(packages []string) map[string][]string {
	categories := map[string][]string{
		"pacman":  {},
		"multilib": {},
		"chaotic": {},
		"aur":     {},
		"unknown": {},
	}

	for _, pkg := range packages {
		source := GetPackageSource(pkg)
		categories[source] = append(categories[source], pkg)
	}

	return categories
}

// CheckParuInstalled verifica si paru está instalado
func CheckParuInstalled() bool {
	return utils.CommandExists("paru")
}

// OfferInstallParu ofrece instalar paru
func OfferInstallParu() bool {
	var install bool
	form := huh.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title("Paru no está instalado").
				Description("Paru es necesario para instalar paquetes desde AUR.\n¿Deseas instalarlo ahora?").
				Affirmative("Sí, instalar").
				Negative("No, cancelar").
				Value(&install),
		),
	)

	if err := form.Run(); err != nil {
		return false
	}

	if !install {
		return false
	}

	// Instalar paru
	fmt.Println(ui.Info("Instalando Paru..."))
	
	// Instalar dependencias
	if err := utils.RunCommand("sudo", "pacman", "-S", "--needed", "--noconfirm", "base-devel", "git"); err != nil {
		fmt.Println(ui.Error("Error instalando dependencias"))
		return false
	}

	// Clonar y compilar
	tmpDir := "/tmp/paru-install"
	os.RemoveAll(tmpDir)
	
	if err := utils.RunCommand("git", "clone", "https://aur.archlinux.org/paru.git", tmpDir); err != nil {
		fmt.Println(ui.Error("Error clonando repositorio"))
		return false
	}

	oldDir, _ := os.Getwd()
	defer os.Chdir(oldDir)

	if err := os.Chdir(tmpDir); err != nil {
		fmt.Println(ui.Error("Error cambiando directorio"))
		os.RemoveAll(tmpDir)
		return false
	}
	
	cmd := exec.Command("makepkg", "-si", "--noconfirm")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		fmt.Println(ui.Error("Error compilando Paru"))
		os.Chdir(oldDir)
		os.RemoveAll(tmpDir)
		return false
	}

	os.Chdir(oldDir)
	os.RemoveAll(tmpDir)

	if CheckParuInstalled() {
		fmt.Println(ui.Success("Paru instalado correctamente"))
		return true
	}

	return false
}

