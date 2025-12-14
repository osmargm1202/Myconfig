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

var scriptsCmd = &cobra.Command{
	Use:   "scripts",
	Short: "Ejecutar scripts de instalación",
	Long:  `Ejecuta los comandos listados en packages/scripts/extra.lst para instalar aplicaciones específicas.`,
	Run:   runScriptsInstall,
}

func init() {
	rootCmd.AddCommand(scriptsCmd)
}

func runScriptsInstall(cmd *cobra.Command, args []string) {
	fmt.Println(ui.Title("Scripts de instalación"))

	// Clonar/actualizar dotfiles con spinner
	if err := utils.CloneOrUpdateDotfilesWithSpinner(); err != nil {
		fmt.Println(ui.Warning(fmt.Sprintf("No se pudo clonar/actualizar dotfiles: %v", err)))
		fmt.Println(ui.Warning("Se intentará continuar con el repositorio existente si está disponible"))
	}

	var groups []packages.PackageGroup
	var parseErr error

	spinner.New().
		Title("Cargando scripts...").
		Action(func() {
			groups, parseErr = packages.ParseLST("scripts", "extra.lst")
		}).
		Run()

	if parseErr != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error cargando scripts: %v", parseErr)))
		return
	}

	if len(groups) == 0 {
		fmt.Println(ui.Warning("No se encontraron scripts para ejecutar"))
		return
	}

	var scripts []string
	for _, g := range groups {
		scripts = append(scripts, g.Packages...)
	}

	if len(scripts) == 0 {
		fmt.Println(ui.Warning("No hay comandos definidos en la lista de scripts"))
		return
	}

	// Crear opciones para multi-select (preseleccionadas)
	var options []huh.Option[string]
	finalSelection := make([]string, len(scripts))
	copy(finalSelection, scripts) // Preseleccionar todos
	for _, script := range scripts {
		options = append(options, huh.NewOption(script, script))
	}

	// Mostrar lista multi-select preseleccionada
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewMultiSelect[string]().
				Title(fmt.Sprintf("Selecciona scripts a ejecutar (%d disponibles)", len(scripts))).
				Description("Todos los scripts están preseleccionados. Deselecciona los que no deseas ejecutar.").
				Options(options...).
				Value(&finalSelection),
		),
	)

	if err := form.Run(); err != nil {
		fmt.Println(ui.Warning("Ejecución cancelada"))
		return
	}

	if len(finalSelection) == 0 {
		fmt.Println(ui.Warning("No se seleccionaron scripts para ejecutar"))
		return
	}

	// Ejecutar solo los scripts seleccionados
	for idx, script := range finalSelection {
		fmt.Println(ui.Info(fmt.Sprintf("(%d/%d) Ejecutando: %s", idx+1, len(finalSelection), script)))
		if err := utils.RunCommand("bash", "-c", script); err != nil {
			fmt.Println(ui.Error(fmt.Sprintf("Error ejecutando script %d: %v", idx+1, err)))
			return
		}
	}

	fmt.Println(ui.Success("Scripts ejecutados correctamente"))
}

