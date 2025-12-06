package main

import (
	"fmt"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/packages"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

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
	fmt.Println(ui.Title("Instalación de i3 Window Manager"))

	// Clonar/actualizar dotfiles con spinner
	if err := utils.CloneOrUpdateDotfilesWithSpinner(); err != nil {
		fmt.Println(ui.Warning(fmt.Sprintf("No se pudo clonar/actualizar dotfiles: %v", err)))
		fmt.Println(ui.Warning("Se intentará continuar con el repositorio existente si está disponible"))
	}

	// Verificar paru antes de continuar
	if !packages.CheckParuInstalled() {
		if !packages.OfferInstallParu() {
			fmt.Println(ui.Warning("Instalación cancelada. Paru es necesario para instalar paquetes AUR."))
			return
		}
	}

	// Cargar paquetes desde LST
	groups, err := packages.ParseLST("arch", "pkg_i3.lst")
	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error cargando paquetes: %v", err)))
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
		fmt.Println(ui.Success("Todos los paquetes de i3 ya están instalados"))
		return
	}

	// Mostrar paquetes a instalar
	fmt.Println(ui.Info(fmt.Sprintf("Paquetes a instalar (%d):", len(toInstall))))
	for _, pkg := range toInstall {
		fmt.Println(ui.Dim(fmt.Sprintf("  • %s", pkg)))
	}

	// Confirmación
	var confirm bool
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title(fmt.Sprintf("Se instalarán %d paquetes", len(toInstall))).
				Affirmative("Instalar").
				Negative("Cancelar").
				Value(&confirm),
		),
	)

	if err := form.Run(); err != nil || !confirm {
		fmt.Println(ui.Warning("Instalación cancelada"))
		return
	}

	// Categorizar e instalar
	categories := packages.CategorizePackages(toInstall)
	if err := packages.InstallCategorized(categories); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
		return
	}

	fmt.Println(ui.Success("i3 y componentes instalados correctamente"))
}
