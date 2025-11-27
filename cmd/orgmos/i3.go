package main

import (
	"fmt"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/packages"
	"orgmos/internal/ui"
)

var i3Packages = []string{
	"i3-wm",
	"dunst",
	"polybar",
	"rofi",
	"picom",
	"feh",
	"xwallpaper",
	"i3lock-color",
	"brightnessctl",
	"udiskie",
	"scrot",
	"maim",
	"xclip",
	"clipmenu",
	"arandr",
	"autorandr",
	"flameshot",
	"xorg-xrandr",
	"xorg-xinput",
	"xorg-xsetroot",
}

var i3Cmd = &cobra.Command{
	Use:   "i3",
	Short: "Instalar i3 y sus componentes",
	Long:  `Instala i3-wm junto con todas las herramientas necesarias: dunst, polybar, rofi, picom, etc.`,
	Run:   runI3Install,
}

var (
	i3WallpaperCmd = &cobra.Command{
		Use:   "wallpaper [random|restore|ruta]",
		Short: "Cambiar wallpaper (solo i3)",
		Run:   runChangeWallpaper,
	}
	i3LockCmd = &cobra.Command{
		Use:   "lock",
		Short: "Bloquear pantalla (i3lock)",
		Run:   runLock,
	}
	i3HotkeyCmd = &cobra.Command{
		Use:   "hotkey",
		Short: "Mostrar atajos configurados en i3",
		Run:   runHotkey,
	}
	i3PowermenuCmd = &cobra.Command{
		Use:   "powermenu",
		Short: "Mostrar menú de energía (rofi)",
		Run:   runPowerMenu,
	}
	i3MemoryCmd = &cobra.Command{
		Use:   "memory",
		Short: "Imprimir uso de memoria",
		Run:   runMemory,
	}
	i3ReloadCmd = &cobra.Command{
		Use:   "reload",
		Short: "Recargar i3 y polybar",
		Run:   runReload,
	}
)

func init() {
	rootCmd.AddCommand(i3Cmd)
	i3Cmd.AddCommand(i3WallpaperCmd)
	i3Cmd.AddCommand(i3LockCmd)
	i3Cmd.AddCommand(i3HotkeyCmd)
	i3Cmd.AddCommand(i3PowermenuCmd)
	i3Cmd.AddCommand(i3MemoryCmd)
	i3Cmd.AddCommand(i3ReloadCmd)
}

func runI3Install(cmd *cobra.Command, args []string) {
	logger.InitOnError("i3")

	fmt.Println(ui.Title("Instalación de i3 Window Manager"))

	// Verificar paquetes instalados
	fmt.Println(ui.Info("Verificando paquetes instalados..."))
	installed := packages.CheckInstalledPacman(i3Packages)

	var toInstall []string
	for _, pkg := range i3Packages {
		if !installed[pkg] {
			toInstall = append(toInstall, pkg)
		}
	}

	if len(toInstall) == 0 {
		fmt.Println(ui.Success("Todos los paquetes de i3 ya están instalados"))
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
		logger.Error("Error instalando i3: %v", err)
		return
	}

	fmt.Println(ui.Success("i3 y componentes instalados correctamente"))
	logger.Info("Instalación i3 completada")
}
