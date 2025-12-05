package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/packages"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var archCmd = &cobra.Command{
	Use:   "arch",
	Short: "Instalar herramientas de terminal para Arch",
	Long:  `Instala fish, kitty, starship, eza, bat, fzf y otras herramientas modernas de terminal.`,
	Run:   runArchInstall,
}

func init() {
	rootCmd.AddCommand(archCmd)
}

func runArchInstall(cmd *cobra.Command, args []string) {
	fmt.Println(ui.Title("Herramientas de Terminal - Arch Linux"))

	// Verificar paru antes de continuar
	if !packages.CheckParuInstalled() {
		if !packages.OfferInstallParu() {
			fmt.Println(ui.Warning("Instalación cancelada. Paru es necesario para instalar paquetes AUR."))
			return
		}
	}

	// Cargar paquetes desde TOML
	groups, err := packages.ParseTOML("pkg_arch.toml")
	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error cargando paquetes: %v", err)))
		return
	}

	// Obtener todos los paquetes
	var archPackages []string
	for _, g := range groups {
		archPackages = append(archPackages, g.Packages...)
	}

	// Verificar paquetes instalados
	fmt.Println(ui.Info("Verificando paquetes..."))
	installed := packages.CheckInstalledPacman(archPackages)

	var toInstall []string
	for _, pkg := range archPackages {
		if !installed[pkg] {
			toInstall = append(toInstall, pkg)
		}
	}

	if len(toInstall) == 0 {
		fmt.Println(ui.Success("Todas las herramientas ya están instaladas"))
		offerFishShellSwitch()
		return
	}

	// Mostrar paquetes a instalar
	fmt.Println(ui.Info(fmt.Sprintf("Paquetes a instalar (%d):", len(toInstall))))
	for _, pkg := range toInstall {
		fmt.Println(ui.Dim(fmt.Sprintf("  • %s", pkg)))
	}

	// Confirmación
	var confirm bool
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title(fmt.Sprintf("Se instalarán %d paquetes", len(toInstall))).
				Affirmative("Instalar").
				Negative("Cancelar").
				Value(&confirm),
		),
	)

	if err := form.Run(); err != nil || !confirm {
		fmt.Println(ui.Warning("Instalación cancelada"))
		return
	}

	// Categorizar e instalar
	categories := packages.CategorizePackages(toInstall)
	if err := packages.InstallCategorized(categories); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
		return
	}

	fmt.Println(ui.Success("Herramientas instaladas correctamente"))
	offerFishShellSwitch()
}

func offerFishShellSwitch() {
	fishPath, err := exec.LookPath("fish")
	if err != nil {
		return
	}

	currentShell := os.Getenv("SHELL")
	if currentShell == fishPath {
		fmt.Println(ui.Dim("Fish ya es tu shell por defecto"))
		return
	}

	var confirm bool
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title("¿Deseas usar fish como shell por defecto?").
				Description("Se ejecutarán los comandos recomendados para registrarlo y actualizar tu shell de login.").
				Affirmative("Sí, cambiar").
				Negative("No, luego").
				Value(&confirm),
		),
	)

	if err := form.Run(); err != nil || !confirm {
		fmt.Println(ui.Dim("Puedes ejecutar 'chsh -s " + fishPath + "' más tarde."))
		return
	}

	ensureFishRegistered(fishPath)
	if err := utils.RunCommand("chsh", "-s", fishPath); err != nil {
		fmt.Println(ui.Error("No se pudo cambiar el shell automáticamente. Ejecuta: chsh -s " + fishPath))
		return
	}

	fmt.Println(ui.Success("Shell predeterminado actualizado a fish"))
}

func ensureFishRegistered(fishPath string) {
	data, err := os.ReadFile("/etc/shells")
	if err == nil && strings.Contains(string(data), fishPath) {
		return
	}

	cmd := exec.Command("bash", "-c", "command -v fish | sudo tee -a /etc/shells >/dev/null")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		fmt.Println(ui.Warning("No se pudo registrar fish en /etc/shells automáticamente"))
	}
}
