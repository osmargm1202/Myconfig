package main

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/packages"
	"orgmos/internal/ui"
)

var niriCmd = &cobra.Command{
	Use:   "niri",
	Short: "Instalar Niri Window Manager",
	Long:  `Instala Niri junto con todas las herramientas necesarias para Wayland.`,
	Run:   runNiriInstall,
}

func init() {
	rootCmd.AddCommand(niriCmd)
}

func runNiriInstall(cmd *cobra.Command, args []string) {
	logger.InitOnError("niri")

	// Verificar paru antes de continuar
	if !packages.CheckParuInstalled() {
		if !packages.OfferInstallParu() {
			fmt.Println(ui.Warning("Instalación cancelada. Paru es necesario para instalar paquetes AUR."))
			return
		}
	}

	fmt.Println(ui.Title("Instalación de Niri Window Manager"))

	// Cargar paquetes desde TOML
	groups, err := packages.ParseTOML("pkg_niri.toml")
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
		fmt.Println(ui.Success("Todos los paquetes de Niri ya están instalados"))
		enableNiriService()
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
		logger.Error("Error instalando Niri: %v", err)
		return
	}

	// Habilitar servicio de usuario
	enableNiriService()

	fmt.Println(ui.Success("Niri y DMS Shell instalados correctamente"))
	fmt.Println(ui.Info("Reinicia tu sesión o ejecuta: systemctl --user start niri.service"))
	logger.Info("Instalación Niri completada")
}

func enableNiriService() {
	fmt.Println(ui.Info("Habilitando servicio Niri..."))

	// Agregar dms como dependencia del servicio
	cmd := exec.Command("systemctl", "--user", "add-wants", "niri.service", "dms")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Println(ui.Warning("No se pudo agregar dms como dependencia (puede que ya esté configurado)"))
		logger.Warn("Error agregando dms: %v", err)
	} else {
		fmt.Println(ui.Success("Servicio Niri configurado"))
		logger.Info("Servicio Niri habilitado con dms")
	}
}
