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

var extrasCmd = &cobra.Command{
	Use:   "extras",
	Short: "Instalar paquetes extras",
	Long:  `Instala todas las herramientas extras definidas en pkg_extras.toml.`,
	Run:   runExtrasInstall,
}

func init() {
	rootCmd.AddCommand(extrasCmd)
}

func runExtrasInstall(cmd *cobra.Command, args []string) {
	fmt.Println(ui.Title("Paquetes Extras"))

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

	// Cargar grupos de paquetes
	var groups []packages.PackageGroup
	var installedMap map[string]bool
	var parseErr error

	// Spinner mientras verifica
	spinner.New().
		Title("Verificando paquetes instalados...").
		Action(func() {
			groups, parseErr = packages.ParseLST("arch", "pkg_extras.lst")
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
		fmt.Println(ui.Success("Todos los paquetes extras ya están instalados"))
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

	fmt.Println(ui.Success("Paquetes extras instalados correctamente"))
}

