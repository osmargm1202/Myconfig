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
	"orgmos/internal/utils"
)

var paruCmd = &cobra.Command{
	Use:   "paru",
	Short: "Instalar Paru AUR Helper",
	Long:  `Instala Paru, un ayudante AUR rápido y simple escrito en Rust.`,
	Run:   runParuInstall,
}

func init() {
	rootCmd.AddCommand(paruCmd)
}

func runParuInstall(cmd *cobra.Command, args []string) {
	logger.InitOnError("paru")

	fmt.Println(ui.Title("Instalación de Paru AUR Helper"))

	// Verificar si ya está instalado
	if packages.CheckParuInstalled() {
		fmt.Println(ui.Success("Paru ya está instalado"))
		output, _ := utils.RunCommandSilent("paru", "--version")
		fmt.Println(ui.Info(output))
		return
	}

	// Confirmación
	var confirm bool
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title("Instalar Paru AUR Helper").
				Description("Paru es necesario para instalar paquetes desde AUR.\n\nPasos:\n  1. Instalar base-devel y git\n  2. Clonar repositorio de Paru\n  3. Compilar e instalar").
				Affirmative("Instalar").
				Negative("Cancelar").
				Value(&confirm),
		),
	)

	if err := form.Run(); err != nil || !confirm {
		fmt.Println(ui.Warning("Instalación cancelada"))
		return
	}

	// Paso 1: Instalar dependencias
	fmt.Println(ui.Info("Instalando dependencias (base-devel, git)..."))
	if err := utils.RunCommand("sudo", "pacman", "-S", "--needed", "--noconfirm", "base-devel", "git"); err != nil {
		fmt.Println(ui.Error("Error instalando dependencias"))
		logger.Error("Error: %v", err)
		return
	}

	// Paso 2: Clonar repositorio
	tmpDir := "/tmp/paru-install"
	fmt.Println(ui.Info("Clonando repositorio de Paru..."))
	
	// Limpiar directorio temporal si existe
	os.RemoveAll(tmpDir)
	
	if err := utils.RunCommand("git", "clone", "https://aur.archlinux.org/paru.git", tmpDir); err != nil {
		fmt.Println(ui.Error("Error clonando repositorio"))
		logger.Error("Error: %v", err)
		return
	}

	// Paso 3: Compilar e instalar
	fmt.Println(ui.Info("Compilando e instalando Paru..."))
	oldDir, _ := os.Getwd()
	defer os.Chdir(oldDir)

	if err := os.Chdir(tmpDir); err != nil {
		fmt.Println(ui.Error("Error cambiando directorio"))
		return
	}

	// Ejecutar makepkg -si
	makepkgCmd := exec.Command("makepkg", "-si", "--noconfirm")
	makepkgCmd.Stdout = os.Stdout
	makepkgCmd.Stderr = os.Stderr
	makepkgCmd.Stdin = os.Stdin

	if err := makepkgCmd.Run(); err != nil {
		fmt.Println(ui.Error("Error compilando Paru"))
		logger.Error("Error: %v", err)
		os.Chdir(oldDir)
		os.RemoveAll(tmpDir)
		return
	}

	// Limpiar
	os.Chdir(oldDir)
	os.RemoveAll(tmpDir)

	// Verificar instalación
	if packages.CheckParuInstalled() {
		fmt.Println(ui.Success("Paru instalado correctamente"))
		output, _ := utils.RunCommandSilent("paru", "--version")
		fmt.Println(ui.Info(output))
		logger.Info("Paru instalado exitosamente")
	} else {
		fmt.Println(ui.Error("Paru no se pudo instalar correctamente"))
		logger.Error("Paru no encontrado después de la instalación")
	}
}

