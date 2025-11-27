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

var swayCmd = &cobra.Command{
	Use:   "sway",
	Short: "Instalar Sway Window Manager",
	Long:  `Instala Sway junto con todas las herramientas necesarias para Wayland, incluyendo dms-shell y quickshell.`,
	Run:   runSwayInstall,
}

func init() {
	rootCmd.AddCommand(swayCmd)
}

func runSwayInstall(cmd *cobra.Command, args []string) {
	logger.InitOnError("sway")

	// Verificar paru antes de continuar
	if !packages.CheckParuInstalled() {
		if !packages.OfferInstallParu() {
			fmt.Println(ui.Warning("Instalación cancelada. Paru es necesario para instalar paquetes AUR."))
			return
		}
	}

	fmt.Println(ui.Title("Instalación de Sway Window Manager"))

	// Cargar paquetes desde TOML
	groups, err := packages.ParseTOML("pkg_sway.toml")
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
		fmt.Println(ui.Success("Todos los paquetes de Sway ya están instalados"))
		enableSwayServices()
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
		logger.Error("Error instalando Sway: %v", err)
		return
	}

	// Habilitar servicios necesarios
	enableSwayServices()

	fmt.Println(ui.Success("Sway y DMS Shell instalados correctamente"))
	fmt.Println(ui.Info("Para iniciar Sway, inicia sesión desde tu display manager o ejecuta: sway"))
	fmt.Println(ui.Info("Asegúrate de tener configurado tu display manager (SDDM, GDM, etc.) para iniciar Sway"))
	logger.Info("Instalación Sway completada")
}

func enableSwayServices() {
	fmt.Println(ui.Info("Configurando servicios de Sway..."))

	// Agregar dms como dependencia del servicio sway si existe
	// Nota: Sway no tiene un servicio systemd por defecto, pero dms puede tener uno
	cmd := exec.Command("systemctl", "--user", "enable", "--now", "dms")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Println(ui.Warning("No se pudo habilitar el servicio dms (puede que no exista o ya esté configurado)"))
		logger.Warn("Error habilitando dms: %v", err)
	} else {
		fmt.Println(ui.Success("Servicio dms habilitado"))
		logger.Info("Servicio dms habilitado")
	}

	// Habilitar swayidle si está disponible
	cmd = exec.Command("systemctl", "--user", "enable", "--now", "swayidle")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Println(ui.Info("swayidle no tiene servicio systemd (se ejecuta desde la configuración de Sway)"))
		logger.Info("swayidle se ejecutará desde la configuración de Sway")
	}
}

