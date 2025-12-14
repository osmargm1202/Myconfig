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

	// Clonar/actualizar dotfiles con spinner
	if err := utils.CloneOrUpdateDotfilesWithSpinner(); err != nil {
		fmt.Println(ui.Warning(fmt.Sprintf("No se pudo clonar/actualizar dotfiles: %v", err)))
		fmt.Println(ui.Warning("Se intentará continuar con el repositorio existente si está disponible"))
	}

	// Seleccionar instalador
	var installer string
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title("Selecciona el instalador").
				Description("Elige el gestor de paquetes que deseas usar").
				Options(
					huh.NewOption("pacman (solo repos oficiales)", "pacman"),
					huh.NewOption("paru (AUR + repos oficiales)", "paru"),
					huh.NewOption("yay (AUR + repos oficiales)", "yay"),
				).
				Value(&installer),
		),
	)

	if err := form.Run(); err != nil {
		fmt.Println(ui.Warning("Instalación cancelada"))
		return
	}

	// Verificar que el instalador existe
	if !packages.CheckInstallerAvailable(installer) {
		if installer == "paru" {
			// Intentar compilar paru
			fmt.Println(ui.Info("Paru no está instalado. Intentando compilar..."))
			if !packages.OfferInstallParu() {
				// Si falla, ofrecer yay como fallback
				fmt.Println(ui.Warning("No se pudo compilar paru. ¿Deseas usar yay como alternativa?"))
				var useYay bool
				form2 := ui.NewForm(
					huh.NewGroup(
						huh.NewConfirm().
							Title("Usar yay como alternativa").
							Description("yay puede instalar paquetes AUR y repos oficiales").
							Affirmative("Sí, usar yay").
							Negative("No, cancelar").
							Value(&useYay),
					),
				)
				if err := form2.Run(); err != nil || !useYay {
					fmt.Println(ui.Warning("Instalación cancelada"))
					return
				}
				if !packages.CheckYayInstalled() {
					fmt.Println(ui.Error("yay no está instalado. Instálalo primero con: yay -S yay"))
					return
				}
				installer = "yay"
			}
		} else {
			fmt.Println(ui.Error(fmt.Sprintf("%s no está instalado. Instálalo primero.", installer)))
			return
		}
	}

	// Cargar paquetes desde LST
	groups, err := packages.ParseLST("arch", "pkg_base.lst")
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

	// Crear opciones para multi-select (preseleccionadas)
	var options []huh.Option[string]
	finalSelection := make([]string, len(toInstall))
	copy(finalSelection, toInstall) // Preseleccionar todos
	for _, pkg := range toInstall {
		options = append(options, huh.NewOption(pkg, pkg))
	}

	// Mostrar lista multi-select preseleccionada
	form3 := ui.NewForm(
		huh.NewGroup(
			huh.NewMultiSelect[string]().
				Title(fmt.Sprintf("Selecciona paquetes a instalar (%d disponibles)", len(toInstall))).
				Description("Todos los paquetes están preseleccionados. Deselecciona los que no deseas instalar.").
				Options(options...).
				Value(&finalSelection),
		),
	)

	if err := form3.Run(); err != nil {
		fmt.Println(ui.Warning("Instalación cancelada"))
		return
	}

	if len(finalSelection) == 0 {
		fmt.Println(ui.Warning("No se seleccionaron paquetes para instalar"))
		return
	}

	// Instalar todos los paquetes seleccionados en una sola corrida
	if err := packages.InstallAllPackages(installer, finalSelection); err != nil {
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
