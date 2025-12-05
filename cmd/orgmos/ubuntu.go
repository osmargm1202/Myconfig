package main

import (
	"fmt"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/huh/spinner"
	"github.com/spf13/cobra"

	"orgmos/internal/packages"
	"orgmos/internal/ui"
)

var ubuntuCmd = &cobra.Command{
	Use:   "ubuntu",
	Short: "Comandos para Ubuntu",
	Long:  `Comandos específicos para instalación de paquetes en Ubuntu.`,
}

var ubuntuBaseCmd = &cobra.Command{
	Use:   "base",
	Short: "Instalar paquetes base para Ubuntu",
	Long:  `Instala herramientas de terminal y sistema base para Ubuntu.`,
	Run:   runUbuntuBase,
}

var ubuntuGeneralCmd = &cobra.Command{
	Use:   "general",
	Short: "Instalar paquetes generales para Ubuntu",
	Long:  `Instala paquetes generales del sistema para Ubuntu.`,
	Run:   runUbuntuGeneral,
}

var ubuntuExtrasCmd = &cobra.Command{
	Use:   "extras",
	Short: "Instalar paquetes extras para Ubuntu",
	Long:  `Instala paquetes extras y utilidades para Ubuntu.`,
	Run:   runUbuntuExtras,
}

var ubuntuNetworkCmd = &cobra.Command{
	Use:   "network",
	Short: "Instalar herramientas de red para Ubuntu",
	Long:  `Instala herramientas de red y seguridad para Ubuntu.`,
	Run:   runUbuntuNetwork,
}

func init() {
	rootCmd.AddCommand(ubuntuCmd)
	ubuntuCmd.AddCommand(ubuntuBaseCmd)
	ubuntuCmd.AddCommand(ubuntuGeneralCmd)
	ubuntuCmd.AddCommand(ubuntuExtrasCmd)
	ubuntuCmd.AddCommand(ubuntuNetworkCmd)
}

func runUbuntuBase(cmd *cobra.Command, args []string) {
	runUbuntuInstall("pkg_base.toml", "Paquetes Base - Ubuntu")
}

func runUbuntuGeneral(cmd *cobra.Command, args []string) {
	runUbuntuInstall("pkg_general.toml", "Paquetes Generales - Ubuntu")
}

func runUbuntuExtras(cmd *cobra.Command, args []string) {
	runUbuntuInstall("pkg_extras.toml", "Paquetes Extras - Ubuntu")
}

func runUbuntuNetwork(cmd *cobra.Command, args []string) {
	runUbuntuInstall("pkg_networks.toml", "Herramientas de Red - Ubuntu")
}

func runUbuntuInstall(configFile string, title string) {
	fmt.Println(ui.Title(title))

	// Cargar grupos de paquetes
	var groups []packages.PackageGroup
	var installedMap map[string]bool

	// Spinner mientras verifica
	spinner.New().
		Title("Verificando paquetes instalados...").
		Action(func() {
			var err error
			groups, err = packages.ParseTOMLWithDistro("ubuntu", configFile)
			if err != nil {
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

// runUbuntuMenu muestra el submenú de Ubuntu
func runUbuntuMenu() {
	for {
		fmt.Print("\033[H\033[2J") // Clear screen
		fmt.Println(ui.Title("ORGMOS - Ubuntu"))
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
						huh.NewOption("Copiar configuraciones", "config"),
						huh.NewOption("Copiar wallpapers", "assets"),
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
			runUbuntuBase(nil, nil)
		case "general":
			runUbuntuGeneral(nil, nil)
		case "extras":
			runUbuntuExtras(nil, nil)
		case "network":
			runUbuntuNetwork(nil, nil)
		case "config":
			runConfigCopy(nil, nil)
		case "assets":
			runAssetsCopy(nil, nil)
		case "back":
			return
		}

		// Pausa antes de volver al menú
		fmt.Println()
		fmt.Println(ui.Dim("Presiona Enter para continuar..."))
		fmt.Scanln()
	}
}

