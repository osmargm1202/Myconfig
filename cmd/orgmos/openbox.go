package main

import (
	"fmt"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/packages"
	"orgmos/internal/ui"
)

var openboxCmd = &cobra.Command{
	Use:   "openbox",
	Short: "Instalar Openbox Window Manager",
	Long:  `Instala Openbox junto con todas las herramientas necesarias.`,
	Run:   runOpenboxInstall,
}

func init() {
	rootCmd.AddCommand(openboxCmd)
}

func runOpenboxInstall(cmd *cobra.Command, args []string) {
	logger.InitOnError("openbox")

	// Verificar paru antes de continuar (por si hay paquetes AUR)
	if !packages.CheckParuInstalled() {
		if !packages.OfferInstallParu() {
			fmt.Println(ui.Warning("Instalación cancelada. Paru es necesario para instalar paquetes AUR."))
			return
		}
	}

	fmt.Println(ui.Title("Instalación de Openbox Window Manager"))

	// Cargar paquetes desde TOML
	groups, err := packages.ParseTOML("pkg_openbox.toml")
	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error cargando paquetes: %v", err)))
		logger.Error("Error parseando TOML: %v", err)
		return
	}

	// Obtener todos los paquetes
	var allPackages []string
	for _, g := range groups {
		allPackages = append(allPackages, g.Packages...)
	}

	// Verificar paquetes instalados
	fmt.Println(ui.Info("Verificando paquetes instalados..."))
	installed := packages.CheckInstalledPacman(allPackages)

	var toInstall []string
	for _, pkg := range allPackages {
		if !installed[pkg] {
			toInstall = append(toInstall, pkg)
		}
	}

	if len(toInstall) == 0 {
		fmt.Println(ui.Success("Todos los paquetes de Openbox ya están instalados"))
		return
	}

	// Confirmación con lista de paquetes
	var confirm bool
	pkgList := ""
	for i, pkg := range toInstall {
		if i > 0 && i%3 == 0 {
			pkgList += "\n"
		}
		pkgList += fmt.Sprintf("  • %s", pkg)
		if i < len(toInstall)-1 {
			pkgList += "  "
		}
	}

	form := ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title(fmt.Sprintf("Se instalarán %d paquetes", len(toInstall))).
				Description(fmt.Sprintf("Paquetes a instalar:\n%s", pkgList)).
				Affirmative("Instalar").
				Negative("Cancelar").
				Value(&confirm),
		),
	)

	if err := form.Run(); err != nil {
		fmt.Println(ui.Error("Error en formulario"))
		return
	}

	if !confirm {
		fmt.Println(ui.Warning("Instalación cancelada"))
		return
	}

	// Categorizar e instalar
	categories := packages.CategorizePackages(toInstall)
	if err := packages.InstallCategorized(categories); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
		logger.Error("Error instalando Openbox: %v", err)
		return
	}

	fmt.Println(ui.Success("Openbox y componentes instalados correctamente"))
	fmt.Println(ui.Info("Configura Openbox desde el menú de aplicaciones o ejecuta: obconf-qt"))
	logger.Info("Instalación Openbox completada")
}

