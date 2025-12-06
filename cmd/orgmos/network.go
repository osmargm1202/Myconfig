package main

import (
	"fmt"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/huh/spinner"
	"github.com/spf13/cobra"

	"orgmos/internal/packages"
	"orgmos/internal/ui"
)

var networkCmd = &cobra.Command{
	Use:   "network",
	Short: "Instalar herramientas de red y seguridad",
	Long:  `Instala todas las herramientas de red definidas en pkg_networks.toml.`,
	Run:   runNetworkInstall,
}

func init() {
	rootCmd.AddCommand(networkCmd)
}

func runNetworkInstall(cmd *cobra.Command, args []string) {
	// Verificar paru antes de continuar
	if !packages.CheckParuInstalled() {
		if !packages.OfferInstallParu() {
			fmt.Println(ui.Warning("Instalación cancelada. Paru es necesario para instalar paquetes AUR."))
			return
		}
	}

	fmt.Println(ui.Title("Herramientas de Red y Seguridad"))

	// Cargar grupos de paquetes
	var groups []packages.PackageGroup
	var installedMap map[string]bool
	var parseErr error

	// Spinner mientras verifica
	spinner.New().
		Title("Verificando paquetes instalados...").
		Action(func() {
			groups, parseErr = packages.ParseTOML("pkg_networks.toml")
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
		fmt.Println(ui.Success("Todas las herramientas de red ya están instaladas"))
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

	// Instalar
	if err := packages.InstallCategorized(categories); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
		return
	}

	fmt.Println(ui.Success("Herramientas de red instaladas correctamente"))
}

