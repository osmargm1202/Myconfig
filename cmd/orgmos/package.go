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

var packageCmd = &cobra.Command{
	Use:     "general",
	Aliases: []string{"package"},
	Short:   "Instalar paquetes generales",
	Long:    `Instala todos los paquetes definidos en pkg_general.toml.`,
	Run:     runPackageInstall,
}

func init() {
	rootCmd.AddCommand(packageCmd)
}

func runPackageInstall(cmd *cobra.Command, args []string) {
	// Verificar paru antes de continuar
	if !packages.CheckParuInstalled() {
		if !packages.OfferInstallParu() {
			fmt.Println(ui.Warning("Instalación cancelada. Paru es necesario para instalar paquetes AUR."))
			return
		}
	}

	fmt.Println(ui.Title("Instalador de Paquetes Generales"))

	// Clonar/actualizar dotfiles con spinner
	if err := utils.CloneOrUpdateDotfilesWithSpinner(); err != nil {
		fmt.Println(ui.Warning(fmt.Sprintf("No se pudo clonar/actualizar dotfiles: %v", err)))
		fmt.Println(ui.Warning("Se intentará continuar con el repositorio existente si está disponible"))
	}

	// Cargar grupos de paquetes
	var groups []packages.PackageGroup
	var installedMap map[string]bool
	var parseErr error

	// Spinner mientras verifica
	spinner.New().
		Title("Verificando paquetes instalados...").
		Action(func() {
			groups, parseErr = packages.ParseLST("arch", "pkg_general.lst")
			if parseErr != nil {
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

	if parseErr != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error cargando paquetes: %v", parseErr)))
		return
	}

	if len(groups) == 0 {
		fmt.Println(ui.Error("No se pudieron cargar los grupos de paquetes"))
		return
	}

	// Filtrar paquetes no instalados
	var toInstall []string
	for _, group := range groups {
		for _, pkg := range group.Packages {
			if !installedMap[pkg] {
				toInstall = append(toInstall, pkg)
			}
		}
	}

	if len(toInstall) == 0 {
		fmt.Println(ui.Success("Todos los paquetes ya están instalados"))
		return
	}

	// Mostrar paquetes a instalar
	fmt.Println(ui.Info(fmt.Sprintf("Paquetes a instalar (%d):", len(toInstall))))
	for _, pkg := range toInstall {
		fmt.Println(ui.Dim(fmt.Sprintf("  • %s", pkg)))
	}

	// Confirmación final
	var confirm bool
	ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title(fmt.Sprintf("Se instalarán %d paquetes", len(toInstall))).
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
	categories := packages.CategorizePackages(toInstall)

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
}
