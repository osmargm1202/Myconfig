package packages

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/charmbracelet/huh"

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

// CheckInstalledApt verifica paquetes instalados con apt (Debian/Ubuntu)
func CheckInstalledApt(packages []string) map[string]bool {
	installed := make(map[string]bool)

	// Obtener lista de paquetes instalados
	output, err := utils.RunCommandSilent("dpkg-query", "-W", "-f=${Package}\n")
	if err != nil {
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

// GetAptPackageDescription obtiene la descripción de un paquete apt
func GetAptPackageDescription(pkg string) string {
	output, err := utils.RunCommandSilent("apt-cache", "show", pkg)
	if err == nil {
		lines := strings.Split(output, "\n")
		for _, line := range lines {
			if strings.HasPrefix(line, "Description:") {
				return strings.TrimSpace(strings.TrimPrefix(line, "Description:"))
			}
		}
	}
	return ""
}

// CheckInstalledFlatpak verifica apps Flatpak instaladas
func CheckInstalledFlatpak(packages []string) map[string]bool {
	installed := make(map[string]bool)

	output, err := utils.RunCommandSilent("flatpak", "list", "--app", "--columns=application")
	if err != nil {
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
	return GetPackageSourceWithInstaller(pkg, "")
}

// GetPackageSourceWithInstaller determina el origen de un paquete usando un instalador específico
func GetPackageSourceWithInstaller(pkg string, aurInstaller string) string {
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

	// Verificar en AUR usando el instalador especificado o detectar automáticamente
	if aurInstaller != "" {
		if aurInstaller == "paru" && utils.CommandExists("paru") {
			_, err = utils.RunCommandSilent("paru", "-Si", pkg)
			if err == nil {
				return "aur"
			}
		} else if aurInstaller == "yay" && utils.CommandExists("yay") {
			_, err = utils.RunCommandSilent("yay", "-Si", pkg)
			if err == nil {
				return "aur"
			}
		}
	} else {
		// Detección automática: paru primero, luego yay
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
	}

	return "unknown"
}

// CategorizePackages separa paquetes por origen
func CategorizePackages(packages []string) map[string][]string {
	categories := map[string][]string{
		"pacman":   {},
		"multilib": {},
		"chaotic":  {},
		"aur":      {},
		"unknown":  {},
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

// CheckYayInstalled verifica si yay está instalado
func CheckYayInstalled() bool {
	return utils.CommandExists("yay")
}

// CheckInstallerAvailable verifica si un instalador está disponible
func CheckInstallerAvailable(installer string) bool {
	switch installer {
	case "pacman":
		return utils.CommandExists("pacman")
	case "paru":
		return utils.CommandExists("paru")
	case "yay":
		return utils.CommandExists("yay")
	default:
		return false
	}
}

// OfferInstallParu ofrece instalar paru
func OfferInstallParu() bool {
	var install bool
	form := ui.NewForm(
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
	if err := utils.RunCommandWithSudo("pacman", "-S", "--needed", "--noconfirm", "base-devel", "git"); err != nil {
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

// GetFlatpakInfo obtiene el nombre y descripción de una aplicación Flatpak
func GetFlatpakInfo(appID string) (name string, description string) {
	// Intentar obtener información de la app instalada primero
	output, err := utils.RunCommandSilent("flatpak", "info", appID)
	if err == nil {
		lines := strings.Split(output, "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "Name:") {
				name = strings.TrimSpace(strings.TrimPrefix(line, "Name:"))
			}
			if strings.HasPrefix(line, "Description:") {
				description = strings.TrimSpace(strings.TrimPrefix(line, "Description:"))
			}
		}
		if name != "" {
			return name, description
		}
	}

	// Si no está instalada, buscar información en Flathub usando remote-info
	output, err = utils.RunCommandSilent("flatpak", "remote-info", "flathub", appID)
	if err == nil {
		lines := strings.Split(output, "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "Name:") {
				name = strings.TrimSpace(strings.TrimPrefix(line, "Name:"))
			}
			if strings.HasPrefix(line, "Description:") {
				description = strings.TrimSpace(strings.TrimPrefix(line, "Description:"))
			}
		}
		if name != "" {
			return name, description
		}
	}

	// Fallback: intentar con search
	output, err = utils.RunCommandSilent("flatpak", "search", "--columns=name,description", appID)
	if err == nil {
		lines := strings.Split(output, "\n")
		for _, line := range lines {
			if strings.Contains(line, appID) {
				parts := strings.Split(line, "\t")
				if len(parts) >= 2 {
					name = strings.TrimSpace(parts[0])
					description = strings.TrimSpace(parts[1])
					if name != "" {
						return name, description
					}
				}
			}
		}
	}

	// Fallback: usar el ID como nombre
	return appID, ""
}

// GetPackageDescription obtiene la descripción de un paquete Arch
func GetPackageDescription(pkg string) string {
	// Intentar con pacman primero
	output, err := utils.RunCommandSilent("pacman", "-Si", pkg)
	if err == nil {
		lines := strings.Split(output, "\n")
		for _, line := range lines {
			if strings.HasPrefix(line, "Description     :") {
				return strings.TrimSpace(strings.TrimPrefix(line, "Description     :"))
			}
		}
	}

	// Intentar con paru (AUR)
	if utils.CommandExists("paru") {
		output, err = utils.RunCommandSilent("paru", "-Si", pkg)
		if err == nil {
			lines := strings.Split(output, "\n")
			for _, line := range lines {
				if strings.HasPrefix(line, "Description     :") {
					return strings.TrimSpace(strings.TrimPrefix(line, "Description     :"))
				}
			}
		}
	}

	return ""
}
