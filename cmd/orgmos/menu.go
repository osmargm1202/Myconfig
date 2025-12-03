package main

import (
	"errors"
	"fmt"
	"os"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/ui"
)

var menuCmd = &cobra.Command{
	Use:   "menu",
	Short: "Menú interactivo principal",
	Long:  `Muestra un menú interactivo con todas las opciones disponibles.`,
	Run:   runMenu,
}

func init() {
	rootCmd.AddCommand(menuCmd)
}

func runMenu(cmd *cobra.Command, args []string) {
	logger.InitOnError("menu")

	for {
		fmt.Print("\033[H\033[2J") // Clear screen
		fmt.Println(ui.Title("ORGMOS - Sistema de Configuración"))
		fmt.Println()

		var choice string
		form := ui.NewForm(
			huh.NewGroup(
				huh.NewSelect[string]().
					Title("Selecciona una opción").
					Options(
						huh.NewOption("Instalar i3 Window Manager", "i3"),
						huh.NewOption("Instalar Niri Window Manager", "niri"),
						huh.NewOption("Instalador de paquetes", "package"),
						huh.NewOption("Instalador de Flatpak", "flatpak"),
						huh.NewOption("Instalar Paru AUR Helper", "paru"),
						huh.NewOption("Instalar SDDM", "sddm"),
						huh.NewOption("Copiar configuraciones", "config"),
						huh.NewOption("Copiar iconos y wallpapers", "assets"),
						huh.NewOption("Herramientas Arch", "arch"),
						huh.NewOption("Herramientas Ubuntu", "ubuntu"),
						huh.NewOption("Scripts", "scripts"),
						huh.NewOption("Salir", "exit"),
					).
					Value(&choice),
			),
		)

		if err := form.Run(); err != nil {
			if errors.Is(err, huh.ErrUserAborted) {
				continue
			}
			fmt.Println(ui.Error("Error mostrando el menú"))
			return
		}

		switch choice {
		case "i3":
			runI3Install(nil, nil)
		case "niri":
			runNiriInstall(nil, nil)
		case "package":
			runPackageInstall(nil, nil)
		case "flatpak":
			runFlatpakInstall(nil, nil)
		case "paru":
			runParuInstall(nil, nil)
		case "sddm":
			runSddmInstall(nil, nil)
		case "config":
			runConfigCopy(nil, nil)
		case "assets":
			runAssetsCopy(nil, nil)
		case "arch":
			runArchInstall(nil, nil)
		case "ubuntu":
			runUbuntuInstall(nil, nil)
		case "scripts":
			runScriptsMenu()
		case "exit":
			fmt.Println(ui.Success("¡Hasta luego!"))
			os.Exit(0)
		}

		// Pausa antes de volver al menú
		fmt.Println()
		fmt.Println(ui.Dim("Presiona Enter para continuar..."))
		fmt.Scanln()
	}
}

func runScriptsMenu() {
	var script string
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title("Selecciona un script").
				Options(
					huh.NewOption("Cambiar Wallpaper", "change-wallpaper"),
					huh.NewOption("Bloquear Pantalla", "lock"),
					huh.NewOption("Menú de Energía", "powermenu"),
					huh.NewOption("Mostrar Hotkeys", "hotkey"),
					huh.NewOption("Uso de memoria", "memory"),
					huh.NewOption("Volver", "back"),
				).
				Value(&script),
		),
	)

	if err := form.Run(); err != nil || script == "back" {
		return
	}

	// Ejecutar el comando correspondiente
	switch script {
	case "change-wallpaper":
		runChangeWallpaper(nil, []string{"random"})
	case "lock":
		runLock(nil, nil)
	case "powermenu":
		runPowerMenu(nil, nil)
	case "hotkey":
		runHotkey(nil, nil)
	case "memory":
		runMemory(nil, nil)
	}
}
