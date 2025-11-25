package main

import (
	"fmt"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/packages"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var ubuntuPackages = []string{
	// Sistema base
	"git",
	"openssh-client",
	"rsync",
	"ntfs-3g",
	"dosfstools",
	"exfatprogs",
	"man-db",
	"build-essential",
	// Terminal
	"fish",
	"kitty",
	"alacritty",
	// Herramientas (algunas pueden no estar en repos)
	"fzf",
	"ripgrep",
	"fd-find",
	"bat",
	// Editores
	"neovim",
	"nano",
	// Utilidades
	"jq",
	"curl",
	"wget",
}

// Paquetes que requieren instalación especial en Ubuntu
var ubuntuSpecialPackages = map[string]string{
	"starship": "curl -sS https://starship.rs/install.sh | sh -s -- -y",
	"eza":      "cargo install eza",
	"zoxide":   "curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash",
	"lazygit":  "go install github.com/jesseduffield/lazygit@latest",
}

var ubuntuCmd = &cobra.Command{
	Use:   "ubuntu",
	Short: "Instalar herramientas de terminal para Ubuntu",
	Long:  `Instala herramientas de terminal disponibles en repositorios Ubuntu.`,
	Run:   runUbuntuInstall,
}

func init() {
	rootCmd.AddCommand(ubuntuCmd)
}

func runUbuntuInstall(cmd *cobra.Command, args []string) {
	logger.Init("ubuntu")
	defer logger.Close()

	fmt.Println(ui.Title("Herramientas de Terminal - Ubuntu"))

	// Verificar que estamos en Ubuntu/Debian
	if !utils.CommandExists("apt") {
		fmt.Println(ui.Error("Este comando es solo para sistemas basados en Debian/Ubuntu"))
		return
	}

	// Confirmación
	var confirm bool
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title(fmt.Sprintf("Se instalarán %d paquetes", len(ubuntuPackages))).
				Description("Algunos paquetes pueden no estar disponibles").
				Affirmative("Instalar").
				Negative("Cancelar").
				Value(&confirm),
		),
	)

	if err := form.Run(); err != nil || !confirm {
		fmt.Println(ui.Warning("Instalación cancelada"))
		return
	}

	// Instalar con apt
	fmt.Println(ui.Info("Actualizando repositorios..."))
	utils.RunCommand("sudo", "apt", "update")

	fmt.Println(ui.Info("Instalando paquetes..."))
	if err := packages.InstallApt(ubuntuPackages); err != nil {
		logger.Warn("Algunos paquetes pueden haber fallado: %v", err)
	}

	// Instalar paquetes especiales
	fmt.Println(ui.Info("Instalando herramientas adicionales..."))
	for name, command := range ubuntuSpecialPackages {
		fmt.Println(ui.Dim(fmt.Sprintf("Instalando %s...", name)))
		utils.RunCommandSilent("bash", "-c", command)
	}

	fmt.Println(ui.Success("Instalación completada"))
	fmt.Println(ui.Info("Ejecuta 'chsh -s /usr/bin/fish' para cambiar a fish shell"))
	logger.Info("Instalación Ubuntu completada")
}

