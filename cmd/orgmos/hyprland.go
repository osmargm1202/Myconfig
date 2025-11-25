package main

import (
	"fmt"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/packages"
	"orgmos/internal/ui"
)

var hyprlandPackages = []string{
	"hyprland",
	"waybar",
	"wofi",
	"hyprpaper",
	"hyprlock",
	"hypridle",
	"wl-clipboard",
	"cliphist",
	"nwg-displays",
	"swappy",
	"grim",
	"slurp",
	"mako",
	"kitty",
	"dolphin",
	"rofi-wayland",
	"xdg-desktop-portal-hyprland",
	"polkit-kde-agent",
	"qt5-wayland",
	"qt6-wayland",
	"noctalia-shell",
}

var hyprlandCmd = &cobra.Command{
	Use:   "hyprland",
	Short: "Instalar Hyprland y sus componentes",
	Long:  `Instala Hyprland junto con todas las herramientas necesarias para Wayland.`,
	Run:   runHyprlandInstall,
}

func init() {
	rootCmd.AddCommand(hyprlandCmd)
}

func runHyprlandInstall(cmd *cobra.Command, args []string) {
	logger.Init("hyprland")
	defer logger.Close()

	fmt.Println(ui.Title("Instalación de Hyprland"))

	// Verificar paquetes instalados
	fmt.Println(ui.Info("Verificando paquetes instalados..."))
	installed := packages.CheckInstalledPacman(hyprlandPackages)

	var toInstall []string
	for _, pkg := range hyprlandPackages {
		if !installed[pkg] {
			toInstall = append(toInstall, pkg)
		}
	}

	if len(toInstall) == 0 {
		fmt.Println(ui.Success("Todos los paquetes de Hyprland ya están instalados"))
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
		logger.Error("Error instalando Hyprland: %v", err)
		return
	}

	fmt.Println(ui.Success("Hyprland y componentes instalados correctamente"))
	logger.Info("Instalación Hyprland completada")
}

