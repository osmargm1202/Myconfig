package main

import (
	"fmt"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/huh/spinner"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/packages"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var flatpakCmd = &cobra.Command{
	Use:   "flatpak",
	Short: "Instalador de aplicaciones Flatpak",
	Long:  `Permite seleccionar e instalar aplicaciones Flatpak por categorías.`,
	Run:   runFlatpakInstall,
}

func init() {
	rootCmd.AddCommand(flatpakCmd)
}

func runFlatpakInstall(cmd *cobra.Command, args []string) {
	logger.InitOnError("flatpak")

	fmt.Println(ui.Title("Instalador de Flatpak"))

	if !ensureFlatpakInstalled() {
		return
	}

	// Cargar grupos de paquetes
	var groups []packages.PackageGroup
	var installedMap map[string]bool

	// Spinner mientras verifica
	spinner.New().
		Title("Verificando aplicaciones instaladas...").
		Action(func() {
			var err error
			groups, err = packages.ParseTOML("pkg_flatpak.toml")
			if err != nil {
				logger.Error("Error parseando TOML: %v", err)
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

	if len(groups) == 0 {
		fmt.Println(ui.Error("No se pudieron cargar las aplicaciones Flatpak"))
		return
	}

	var selectedPackages []string

	// Iterar por cada grupo
	for _, group := range groups {
		var options []huh.Option[string]

		for _, pkg := range group.Packages {
			// Obtener información de la aplicación
			name, desc := packages.GetFlatpakInfo(pkg)
			
			// Crear etiqueta con nombre real y descripción
			label := pkg
			if name != "" && name != pkg {
				if desc != "" {
					label = fmt.Sprintf("%s - %s (%s)", name, desc, pkg)
				} else {
					label = fmt.Sprintf("%s (%s)", name, pkg)
				}
			} else if desc != "" {
				label = fmt.Sprintf("%s - %s", pkg, desc)
			}
			
			opt := huh.NewOption(label, pkg)
			if installedMap[pkg] {
				opt = opt.Selected(true) // Ya instalado, preseleccionar
			} else {
				opt = opt.Selected(false) // No instalado, no preseleccionar
			}
			options = append(options, opt)
		}

		var selected []string
		form := ui.NewForm(
			huh.NewGroup(
				huh.NewMultiSelect[string]().
					Title(group.Name).
					Description("Ya instalados aparecen marcados").
					Options(options...).
					Value(&selected),
			),
		)

		if err := form.Run(); err != nil {
			continue
		}

		selectedPackages = append(selectedPackages, selected...)
	}

	if len(selectedPackages) == 0 {
		fmt.Println(ui.Warning("No se seleccionaron aplicaciones"))
		return
	}

	// Confirmación final
	var confirm bool
	ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title(fmt.Sprintf("Se instalarán %d aplicaciones Flatpak", len(selectedPackages))).
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
	if err := packages.InstallFlatpak(selectedPackages); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
		return
	}

	fmt.Println(ui.Success("Aplicaciones Flatpak instaladas"))
	logger.Info("Instalación Flatpak completada")
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

