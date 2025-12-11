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

var debianCmd = &cobra.Command{
	Use:   "debian",
	Short: "Comandos para Debian",
	Long:  `Comandos específicos para instalación de paquetes en Debian.`,
}

var debianBaseCmd = &cobra.Command{
	Use:   "base",
	Short: "Instalar paquetes base para Debian",
	Long:  `Instala herramientas de terminal y sistema base para Debian.`,
	Run:   runDebianBase,
}

var debianGeneralCmd = &cobra.Command{
	Use:   "general",
	Short: "Instalar paquetes generales para Debian",
	Long:  `Instala paquetes generales del sistema para Debian.`,
	Run:   runDebianGeneral,
}

var debianExtrasCmd = &cobra.Command{
	Use:   "extras",
	Short: "Instalar paquetes extras para Debian",
	Long:  `Instala paquetes extras y utilidades para Debian.`,
	Run:   runDebianExtras,
}

var debianNetworkCmd = &cobra.Command{
	Use:   "network",
	Short: "Instalar herramientas de red para Debian",
	Long:  `Instala herramientas de red y seguridad para Debian.`,
	Run:   runDebianNetwork,
}

func init() {
	rootCmd.AddCommand(debianCmd)
	debianCmd.AddCommand(debianBaseCmd)
	debianCmd.AddCommand(debianGeneralCmd)
	debianCmd.AddCommand(debianExtrasCmd)
	debianCmd.AddCommand(debianNetworkCmd)
}

func runDebianBase(cmd *cobra.Command, args []string) {
	runDebianInstall("pkg_base.lst", "Paquetes Base - Debian")
}

func runDebianGeneral(cmd *cobra.Command, args []string) {
	runDebianInstall("pkg_general.lst", "Paquetes Generales - Debian")
}

func runDebianExtras(cmd *cobra.Command, args []string) {
	runDebianInstall("pkg_extras.lst", "Paquetes Extras - Debian")
}

func runDebianNetwork(cmd *cobra.Command, args []string) {
	runDebianInstall("pkg_networks.lst", "Herramientas de Red - Debian")
}

func runDebianInstall(configFile string, title string) {
	fmt.Println(ui.Title(title))

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
			groups, parseErr = packages.ParseLST("debian", configFile)
			if parseErr != nil {
				return
			}

			// Obtener todos los paquetes
			var allPkgs []string
			for _, g := range groups {
				allPkgs = append(allPkgs, g.Packages...)
			}

			installedMap = packages.CheckInstalledApt(allPkgs)
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

	// Instalar paquetes
	if err := packages.InstallApt(toInstall); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
		return
	}

	fmt.Println(ui.Success("Instalación completada"))
}

// runDebianMenu muestra el submenú de Debian
func runDebianMenu() {
	for {
		fmt.Print("\033[H\033[2J") // Clear screen
		fmt.Println(ui.Title("ORGMOS - Debian"))
		fmt.Println()

		var choice string
		form := ui.NewForm(
			huh.NewGroup(
				huh.NewSelect[string]().
					Title("Selecciona una opción").
					Options(
						huh.NewOption("Paquetes base", "base"),
						huh.NewOption("Paquetes generales", "general"),
						huh.NewOption("Paquetes extras", "extras"),
						huh.NewOption("Herramientas de red", "network"),
						huh.NewOption("Volver", "back"),
					).
					Value(&choice),
			),
		)

		if err := form.Run(); err != nil {
			return
		}

		switch choice {
		case "base":
			runDebianBase(nil, nil)
		case "general":
			runDebianGeneral(nil, nil)
		case "extras":
			runDebianExtras(nil, nil)
		case "network":
			runDebianNetwork(nil, nil)
		case "back":
			return
		}

		// Pausa antes de volver al menú
		fmt.Println()
		fmt.Println(ui.Dim("Presiona Enter para continuar..."))
		fmt.Scanln()
	}
}
