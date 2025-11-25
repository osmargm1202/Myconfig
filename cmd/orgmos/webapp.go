package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var webappCmd = &cobra.Command{
	Use:   "webapp",
	Short: "WebApp Creator",
	Long:  `Crea aplicaciones web como apps de escritorio.`,
	Run:   runWebapp,
}

func init() {
	rootCmd.AddCommand(webappCmd)

	webappCmd.AddCommand(&cobra.Command{
		Use:   "install",
		Short: "Instalar WebApp Creator como aplicación",
		Run:   runWebappInstall,
	})
}

func runWebapp(cmd *cobra.Command, args []string) {
	logger.Init("webapp")
	defer logger.Close()

	repoDir := utils.GetRepoDir()
	scriptPath := filepath.Join(repoDir, "webapp", "webapp-creator.sh")

	if _, err := os.Stat(scriptPath); os.IsNotExist(err) {
		fmt.Println(ui.Error("WebApp Creator no encontrado"))
		return
	}

	logger.Info("Ejecutando WebApp Creator")

	execCmd := exec.Command("bash", scriptPath)
	execCmd.Stdout = os.Stdout
	execCmd.Stderr = os.Stderr
	execCmd.Stdin = os.Stdin

	if err := execCmd.Run(); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
		logger.Error("Error ejecutando webapp-creator: %v", err)
	}
}

func runWebappInstall(cmd *cobra.Command, args []string) {
	logger.Init("webapp")
	defer logger.Close()

	fmt.Println(ui.Title("Instalar WebApp Creator"))

	homeDir, _ := os.UserHomeDir()
	applicationsDir := filepath.Join(homeDir, ".local", "share", "applications")
	os.MkdirAll(applicationsDir, 0755)

	desktopContent := `[Desktop Entry]
Name=WebApp Creator
Comment=Crear aplicaciones web como apps de escritorio
Exec=orgmos webapp
Terminal=true
Type=Application
Icon=applications-internet
Categories=Development;Utility;
Keywords=webapp;browser;chrome;
`

	desktopPath := filepath.Join(applicationsDir, "webapp-creator.desktop")
	if err := os.WriteFile(desktopPath, []byte(desktopContent), 0755); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
		logger.Error("Error creando desktop file: %v", err)
		return
	}

	fmt.Println(ui.Success("WebApp Creator instalado"))
	fmt.Println(ui.Info(fmt.Sprintf("Desktop file: %s", desktopPath)))
	logger.Info("WebApp Creator instalado")
}

