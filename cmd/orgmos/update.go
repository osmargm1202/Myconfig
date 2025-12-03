package main

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/ui"
)

var updateCmd = &cobra.Command{
	Use:   "update",
	Short: "Actualizar orgmos y orgmai",
	Long:  `Ejecuta el script de instalación remoto para actualizar los binarios`,
	Run:   runUpdate,
}

func init() {
	rootCmd.AddCommand(updateCmd)
}

func runUpdate(cmd *cobra.Command, args []string) {
	logger.InitOnError("update")

	fmt.Println(ui.Title("Actualizar ORGMOS"))

	fmt.Println(ui.Info("Ejecutando script de actualización remoto..."))
	fmt.Println(ui.Dim("URL: https://custom.or-gm.com/arch.sh"))

	// Ejecutar curl y pipe a bash usando shell
	// Usamos sh -c para ejecutar el pipe correctamente
	updateCmd := exec.Command("sh", "-c", "curl -fsSL https://custom.or-gm.com/arch.sh | bash")
	updateCmd.Stdout = os.Stdout
	updateCmd.Stderr = os.Stderr

	if err := updateCmd.Run(); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error ejecutando actualización: %v", err)))
		logger.Error("Error ejecutando actualización: %v", err)
		return
	}

	fmt.Println(ui.Success("Actualización completada"))
	logger.Info("Actualización completada")
}

