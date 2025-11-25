package main

import (
	"fmt"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/huh/spinner"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/packages"
	"orgmos/internal/ui"
)

var packageCmd = &cobra.Command{
	Use:   "package",
	Short: "Instalador interactivo de paquetes",
	Long:  `Permite seleccionar e instalar paquetes por grupos de forma interactiva.`,
	Run:   runPackageInstall,
}

func init() {
	rootCmd.AddCommand(packageCmd)
}

func runPackageInstall(cmd *cobra.Command, args []string) {
	logger.Init("package")
	defer logger.Close()

	// Verificar paru antes de continuar
	if !packages.CheckParuInstalled() {
		if !packages.OfferInstallParu() {
			fmt.Println(ui.Warning("Instalación cancelada. Paru es necesario para instalar paquetes AUR."))
			return
		}
	}

	fmt.Println(ui.Title("Instalador de Paquetes"))

	// Cargar grupos de paquetes
	var groups []packages.PackageGroup
	var installedMap map[string]bool

	// Spinner mientras verifica
	spinner.New().
		Title("Verificando paquetes instalados...").
		Action(func() {
			var err error
			groups, err = packages.ParseTOML("pkg_general.toml")
			if err != nil {
				logger.Error("Error parseando TOML: %v", err)
				return
			}

			// Obtener todos los paquetes
			var allPkgs []string
			for _, g := range groups {
				allPkgs = append(allPkgs, g.Packages...)
			}

			installedMap = packages.CheckInstalledPacman(allPkgs)
		}).
		Run()

	if len(groups) == 0 {
		fmt.Println(ui.Error("No se pudieron cargar los grupos de paquetes"))
		return
	}

	var selectedPackages []string

	// Iterar por cada grupo
	for _, group := range groups {
		var options []huh.Option[string]
		var preSelected []string

		for _, pkg := range group.Packages {
			opt := huh.NewOption(pkg, pkg)
			if installedMap[pkg] {
				opt = opt.Selected(true) // Ya instalado, preseleccionar
				preSelected = append(preSelected, pkg)
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
					Description("Selecciona los paquetes (ya instalados aparecen marcados)").
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
		fmt.Println(ui.Warning("No se seleccionaron paquetes"))
		return
	}

	// Confirmación final
	var confirm bool
	ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title(fmt.Sprintf("Se instalarán %d paquetes", len(selectedPackages))).
				Affirmative("Instalar").
				Negative("Cancelar").
				Value(&confirm),
		),
	).Run()

	if !confirm {
		fmt.Println(ui.Warning("Instalación cancelada"))
		return
	}

	// Categorizar paquetes por origen
	fmt.Println(ui.Info("Categorizando paquetes por origen..."))
	categories := packages.CategorizePackages(selectedPackages)

	// Mostrar resumen
	if len(categories["pacman"]) > 0 {
		fmt.Println(ui.Info(fmt.Sprintf("Repos oficiales: %d", len(categories["pacman"]))))
	}
	if len(categories["multilib"]) > 0 {
		fmt.Println(ui.Warning(fmt.Sprintf("Multilib: %d (requiere multilib habilitado)", len(categories["multilib"]))))
	}
	if len(categories["chaotic"]) > 0 {
		fmt.Println(ui.Warning(fmt.Sprintf("Chaotic-AUR: %d (requiere chaotic-aur)", len(categories["chaotic"]))))
	}
	if len(categories["aur"]) > 0 {
		fmt.Println(ui.Info(fmt.Sprintf("AUR: %d", len(categories["aur"]))))
	}

	// Instalar
	if err := packages.InstallCategorized(categories); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
		return
	}

	fmt.Println(ui.Success("Instalación completada"))
	logger.Info("Instalación de paquetes completada")
}

