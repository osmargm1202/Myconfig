package main

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/packages"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
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
	// Verificar paru antes de continuar
	if !packages.CheckParuInstalled() {
		if !packages.OfferInstallParu() {
			fmt.Println(ui.Warning("Instalación cancelada. Paru es necesario para instalar paquetes AUR."))
			return
		}
	}

	fmt.Println(ui.Title("Instalación de Niri Window Manager"))

	// Clonar/actualizar dotfiles con spinner
	if err := utils.CloneOrUpdateDotfilesWithSpinner(); err != nil {
		fmt.Println(ui.Warning(fmt.Sprintf("No se pudo clonar/actualizar dotfiles: %v", err)))
		fmt.Println(ui.Warning("Se intentará continuar con el repositorio existente si está disponible"))
	}

	// Confirmación antes de ejecutar script curl
	var confirmScript bool
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title("Instalar Niri y DMS Shell").
				Description("Se ejecutará el script de instalación de Dank Linux que instalará niri y dependencias de DMS (dsearch, dgop, etc.).").
				Affirmative("Continuar").
				Negative("Cancelar").
				Value(&confirmScript),
		),
	)

	if err := form.Run(); err != nil || !confirmScript {
		fmt.Println(ui.Warning("Instalación cancelada"))
		return
	}

	// Ejecutar script curl para instalar niri y dependencias de DMS
	fmt.Println(ui.Info("Ejecutando script de instalación de Dank Linux..."))

	// Ejecutar curl y pipe a sh
	curlCmd := exec.Command("curl", "-fsSL", "https://install.danklinux.com")
	shCmd := exec.Command("sh")

	// Conectar stdout de curl a stdin de sh
	shCmd.Stdin, _ = curlCmd.StdoutPipe()
	shCmd.Stdout = os.Stdout
	shCmd.Stderr = os.Stderr

	// Iniciar sh primero
	if err := shCmd.Start(); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error iniciando sh: %v", err)))
		return
	}

	// Ejecutar curl
	if err := curlCmd.Run(); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error ejecutando curl: %v", err)))
		shCmd.Process.Kill()
		return
	}

	// Esperar a que sh termine
	if err := shCmd.Wait(); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error ejecutando script de instalación: %v", err)))
		return
	}

	fmt.Println(ui.Success("Script de instalación completado"))

	// Paquetes que el script curl ya instaló (para filtrarlos)
	curlInstalledPackages := map[string]bool{
		"niri":               true,
		"dms-shell-niri-git": true,
		"dsearch":            true,
		"dgop":               true,
		"quickshell":         true,
		"matugen-git":        true,
		"hyprpicker":         true,
	}

	// Cargar paquetes desde LST
	groups, err := packages.ParseLST("arch", "pkg_niri.lst")
	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error cargando paquetes: %v", err)))
		return
	}

	// Obtener todos los paquetes y filtrar los que ya instaló el script curl
	var allPackages []string
	for _, g := range groups {
		for _, pkg := range g.Packages {
			if !curlInstalledPackages[pkg] {
				allPackages = append(allPackages, pkg)
			}
		}
	}

	// Verificar paquetes instalados
	fmt.Println(ui.Info("Verificando paquetes adicionales instalados..."))
	installed := packages.CheckInstalledPacman(allPackages)

	var toInstall []string
	for _, pkg := range allPackages {
		if !installed[pkg] {
			toInstall = append(toInstall, pkg)
		}
	}

	// Agregar greetd-dms-greeter-git a la lista de instalación (AUR)
	greetdInstalled := packages.CheckInstalledPacman([]string{"greetd-dms-greeter-git"})
	if !greetdInstalled["greetd-dms-greeter-git"] {
		toInstall = append(toInstall, "greetd-dms-greeter-git")
	}

	if len(toInstall) > 0 {
		// Mostrar paquetes a instalar
		fmt.Println(ui.Info(fmt.Sprintf("Paquetes adicionales a instalar (%d):", len(toInstall))))
		for _, pkg := range toInstall {
			fmt.Println(ui.Dim(fmt.Sprintf("  • %s", pkg)))
		}

		// Confirmación
		var confirm bool
		form := ui.NewForm(
			huh.NewGroup(
				huh.NewConfirm().
					Title(fmt.Sprintf("Se instalarán %d paquetes adicionales", len(toInstall))).
					Affirmative("Instalar").
					Negative("Cancelar").
					Value(&confirm),
			),
		)

		if err := form.Run(); err != nil || !confirm {
			fmt.Println(ui.Warning("Instalación de paquetes adicionales cancelada"))
		} else {
			// Categorizar e instalar
			categories := packages.CategorizePackages(toInstall)
			if err := packages.InstallCategorized(categories); err != nil {
				fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
				return
			}
			fmt.Println(ui.Success("Paquetes adicionales instalados correctamente"))
		}
	} else {
		fmt.Println(ui.Success("Todos los paquetes adicionales ya están instalados"))
	}

	// Ejecutar comandos post-instalación de DMS greeter
	fmt.Println(ui.Info("Configurando DMS greeter..."))

	// dms greeter enable
	enableCmd := exec.Command("dms", "greeter", "enable")
	enableCmd.Stdout = os.Stdout
	enableCmd.Stderr = os.Stderr

	if err := enableCmd.Run(); err != nil {
		fmt.Println(ui.Warning(fmt.Sprintf("No se pudo ejecutar 'dms greeter enable': %v", err)))
	} else {
		fmt.Println(ui.Success("DMS greeter habilitado"))
	}

	// dms greeter sync
	syncCmd := exec.Command("dms", "greeter", "sync")
	syncCmd.Stdout = os.Stdout
	syncCmd.Stderr = os.Stderr

	if err := syncCmd.Run(); err != nil {
		fmt.Println(ui.Warning(fmt.Sprintf("No se pudo ejecutar 'dms greeter sync': %v", err)))
	} else {
		fmt.Println(ui.Success("DMS greeter sincronizado"))
	}

	// Habilitar servicio de usuario
	enableNiriService()

	fmt.Println(ui.Success("Niri y DMS Shell instalados correctamente"))
	fmt.Println(ui.Info("Reinicia tu sesión o ejecuta: systemctl --user start niri.service"))
}

func enableNiriService() {
	fmt.Println(ui.Info("Habilitando servicio Niri..."))

	// Agregar dms como dependencia del servicio
	cmd := exec.Command("systemctl", "--user", "add-wants", "niri.service", "dms")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Println(ui.Warning("No se pudo agregar dms como dependencia (puede que ya esté configurado)"))
	} else {
		fmt.Println(ui.Success("Servicio Niri configurado"))
	}
}
