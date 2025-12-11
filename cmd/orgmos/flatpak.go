package main

import (
	"fmt"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/huh/spinner"
	"github.com/spf13/cobra"

	"orgmos/internal/packages"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var flatpakCmd = &cobra.Command{
	Use:   "flatpak",
	Short: "Instalador de aplicaciones Flatpak",
	Long:  `Instala todas las aplicaciones Flatpak definidas en pkg_flatpak.toml.`,
	Run:   runFlatpakInstall,
}

func init() {
	rootCmd.AddCommand(flatpakCmd)
}

func runFlatpakInstall(cmd *cobra.Command, args []string) {
	fmt.Println(ui.Title("Instalador de Flatpak"))

	// Clonar/actualizar dotfiles con spinner
	if err := utils.CloneOrUpdateDotfilesWithSpinner(); err != nil {
		fmt.Println(ui.Warning(fmt.Sprintf("No se pudo clonar/actualizar dotfiles: %v", err)))
		fmt.Println(ui.Warning("Se intentará continuar con el repositorio existente si está disponible"))
	}

	if !ensureFlatpakInstalled() {
		return
	}

	// Cargar grupos de paquetes
	var groups []packages.PackageGroup
	var installedMap map[string]bool
	var parseErr error

	// Spinner mientras verifica
	spinner.New().
		Title("Verificando aplicaciones instaladas...").
		Action(func() {
			groups, parseErr = packages.ParseLST("flatpak", "pkg_flatpak.lst")
			if parseErr != nil {
				return
			}

			// Obtener todos los paquetes
			var allPkgs []string
			for _, g := range groups {
				allPkgs = append(allPkgs, g.Packages...)
			}

			installedMap = packages.CheckInstalledFlatpak(allPkgs)
		}).
		Run()

	if parseErr != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error cargando aplicaciones Flatpak: %v", parseErr)))
		return
	}

	if len(groups) == 0 {
		fmt.Println(ui.Error("No se pudieron cargar las aplicaciones Flatpak"))
		return
	}

	// Filtrar aplicaciones no instaladas
	var toInstall []string
	for _, group := range groups {
		for _, pkg := range group.Packages {
			if !installedMap[pkg] {
				toInstall = append(toInstall, pkg)
			}
		}
	}

	if len(toInstall) == 0 {
		fmt.Println(ui.Success("Todas las aplicaciones Flatpak ya están instaladas"))
		return
	}

	// Mostrar aplicaciones a instalar
	fmt.Println(ui.Info(fmt.Sprintf("Aplicaciones a instalar (%d):", len(toInstall))))
	for _, pkg := range toInstall {
		fmt.Println(ui.Dim(fmt.Sprintf("  • %s", pkg)))
	}

	// Confirmación final
	var confirm bool
	ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title(fmt.Sprintf("Se instalarán %d aplicaciones Flatpak", len(toInstall))).
				Affirmative("Instalar").
				Negative("Cancelar").
				Value(&confirm),
		),
	).Run()

	if !confirm {
		fmt.Println(ui.Warning("Instalación cancelada"))
		return
	}

	// Instalar
	if err := packages.InstallFlatpak(toInstall); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
		return
	}

	fmt.Println(ui.Success("Aplicaciones Flatpak instaladas"))
}

func ensureFlatpakInstalled() bool {
	if utils.CommandExists("flatpak") {
		return true
	}

	fmt.Println(ui.Warning("Flatpak no está instalado. Es necesario para continuar."))

	if !packages.CheckParuInstalled() {
		fmt.Println(ui.Warning("Paru es necesario para instalar Flatpak desde AUR."))
		if !packages.OfferInstallParu() {
			fmt.Println(ui.Error("No se instaló Paru, cancelando."))
			return false
		}
	}

	fmt.Println(ui.Info("Instalando Flatpak con Paru..."))
	if err := utils.RunCommand("paru", "-S", "--noconfirm", "--needed", "flatpak"); err != nil {
		fmt.Println(ui.Error("No se pudo instalar Flatpak"))
		return false
	}

	if !utils.CommandExists("flatpak") {
		fmt.Println(ui.Error("Flatpak sigue sin estar disponible"))
		return false
	}

	fmt.Println(ui.Success("Flatpak instalado correctamente"))
	return true
}
