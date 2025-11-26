package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/packages"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var sddmPackages = []string{
	"sddm",
	"qt5-quickcontrols",
	"qt5-quickcontrols2",
	"qt5-graphicaleffects",
}

var sddmCmd = &cobra.Command{
	Use:   "sddm",
	Short: "Instalar y configurar SDDM",
	Long:  `Instala SDDM como display manager con el tema ORGMOS negro.`,
	Run:   runSddmInstall,
}

func init() {
	rootCmd.AddCommand(sddmCmd)
}

func runSddmInstall(cmd *cobra.Command, args []string) {
	logger.InitOnError("sddm")

	fmt.Println(ui.Title("Instalación de SDDM"))

	// Confirmación
	var confirm bool
	var enableAutologin bool

	form := ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title("Instalar SDDM con tema ORGMOS").
				Description("Se instalará SDDM y se configurará con el tema negro").
				Affirmative("Instalar").
				Negative("Cancelar").
				Value(&confirm),
		),
		huh.NewGroup(
			huh.NewConfirm().
				Title("¿Activar autologin?").
				Description("Inicio automático sin contraseña").
				Affirmative("Sí").
				Negative("No").
				Value(&enableAutologin),
		).WithHideFunc(func() bool { return !confirm }),
	)

	if err := form.Run(); err != nil {
		fmt.Println(ui.Error("Error en formulario"))
		return
	}

	if !confirm {
		fmt.Println(ui.Warning("Instalación cancelada"))
		return
	}

	// Instalar paquetes
	fmt.Println(ui.Info("Instalando SDDM..."))
	if err := packages.InstallPacman(sddmPackages); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error instalando SDDM: %v", err)))
		return
	}

	// Instalar tema
	if err := installSddmTheme(); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error instalando tema: %v", err)))
		return
	}

	// Configurar SDDM
	if err := configureSddm(enableAutologin); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error configurando SDDM: %v", err)))
		return
	}

	// Habilitar servicio
	if err := enableSddmService(); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error habilitando servicio: %v", err)))
		return
	}

	fmt.Println(ui.Success("SDDM instalado y configurado"))
	fmt.Println(ui.Info("Reinicia el sistema para aplicar los cambios"))
	logger.Info("SDDM instalación completada")
}

func installSddmTheme() error {
	repoDir := utils.GetRepoDir()
	themeSource := filepath.Join(repoDir, "sddm", "orgmos-sddm")
	themeDest := "/usr/share/sddm/themes/orgmos-sddm"

	if _, err := os.Stat(themeSource); os.IsNotExist(err) {
		return fmt.Errorf("tema no encontrado: %s", themeSource)
	}

	fmt.Println(ui.Info("Instalando tema ORGMOS..."))

	// Eliminar tema existente
	utils.RunCommandSilent("sudo", "rm", "-rf", themeDest)

	// Crear directorio
	utils.RunCommandSilent("sudo", "mkdir", "-p", "/usr/share/sddm/themes")

	// Copiar tema
	if err := utils.RunCommand("sudo", "cp", "-r", themeSource, themeDest); err != nil {
		return err
	}

	// Aplicar tema negro (panther.conf)
	pantherConf := filepath.Join(themeSource, "panther.conf")
	if _, err := os.Stat(pantherConf); err == nil {
		utils.RunCommand("sudo", "cp", pantherConf, filepath.Join(themeDest, "theme.conf"))
		fmt.Println(ui.Success("Tema negro aplicado"))
	}

	return nil
}

func configureSddm(autologin bool) error {
	fmt.Println(ui.Info("Configurando SDDM..."))

	autologinUser := ""
	if autologin {
		autologinUser = os.Getenv("USER")
	}

	config := fmt.Sprintf(`[Autologin]
Relogin=false
Session=
User=%s

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Theme]
Current=orgmos-sddm

[Users]
MaximumUid=60513
MinimumUid=1000

[X11]
MinimumVT=1
ServerPath=/usr/bin/X
XephyrPath=/usr/bin/Xephyr
SessionCommand=/usr/share/sddm/scripts/Xsession
SessionDir=/usr/share/xsessions
XauthPath=/usr/bin/xauth
XDisplayStop=30
XDisplayStart=0
`, autologinUser)

	// Escribir configuración
	tmpFile := "/tmp/sddm.conf"
	if err := os.WriteFile(tmpFile, []byte(config), 0644); err != nil {
		return err
	}

	return utils.RunCommand("sudo", "cp", tmpFile, "/etc/sddm.conf")
}

func enableSddmService() error {
	fmt.Println(ui.Info("Habilitando servicio SDDM..."))

	// Deshabilitar otros display managers
	otherDms := []string{"gdm", "lightdm", "lxdm", "xdm"}
	for _, dm := range otherDms {
		utils.RunCommandSilent("sudo", "systemctl", "disable", dm)
	}

	// Habilitar SDDM
	return utils.RunCommand("sudo", "systemctl", "enable", "sddm")
}

