package main

import (
	"fmt"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/packages"
	"orgmos/internal/ui"
)

var archPackages = []string{
	// Sistema base
	"git",
	"openssh",
	"rsync",
	"ntfs-3g",
	"dosfstools",
	"exfatprogs",
	"man-db",
	"man-pages",
	"base-devel",
	"pacman-contrib",
	// Terminal
	"fish",
	"kitty",
	"alacritty",
	"starship",
	// Herramientas modernas
	"eza",
	"duf",
	"zoxide",
	"fzf",
	"ripgrep",
	"fd",
	"bat",
	"dysk",
	// Editores
	"neovim",
	"nano",
	// Git/Docker UI
	"lazygit",
	"lazydocker",
	// Utilidades
	"jq",
	"curl",
	"wget",
	"gum",
}

var archCmd = &cobra.Command{
	Use:   "arch",
	Short: "Instalar herramientas de terminal para Arch",
	Long:  `Instala fish, kitty, starship, eza, bat, fzf y otras herramientas modernas de terminal.`,
	Run:   runArchInstall,
}

func init() {
	rootCmd.AddCommand(archCmd)
}

func runArchInstall(cmd *cobra.Command, args []string) {
	logger.Init("arch")
	defer logger.Close()

	// Verificar paru antes de continuar
	if !packages.CheckParuInstalled() {
		if !packages.OfferInstallParu() {
			fmt.Println(ui.Warning("Instalación cancelada. Paru es necesario para instalar paquetes AUR."))
			return
		}
	}

	fmt.Println(ui.Title("Herramientas de Terminal - Arch Linux"))

	// Verificar paquetes instalados
	fmt.Println(ui.Info("Verificando paquetes..."))
	installed := packages.CheckInstalledPacman(archPackages)

	var toInstall []string
	for _, pkg := range archPackages {
		if !installed[pkg] {
			toInstall = append(toInstall, pkg)
		}
	}

	if len(toInstall) == 0 {
		fmt.Println(ui.Success("Todas las herramientas ya están instaladas"))
		return
	}

	// Confirmación
	var confirm bool
	form := huh.NewForm(
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

	fmt.Println(ui.Success("Herramientas instaladas correctamente"))
	fmt.Println(ui.Info("Ejecuta 'chsh -s /usr/bin/fish' para cambiar a fish shell"))
	logger.Info("Instalación Arch completada")
}

