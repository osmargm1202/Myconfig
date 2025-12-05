package main

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/spf13/cobra"

	"orgmos/internal/ui"
)

const installURL = "https://custom.or-gm.com/orgmos.sh"

var updateCmd = &cobra.Command{
	Use:   "update",
	Short: "Actualizar ORGMOS",
	Long:  `Descarga y ejecuta el script de instalación para actualizar ORGMOS a la última versión.`,
	Run:   runUpdate,
}

func init() {
	rootCmd.AddCommand(updateCmd)
}

func runUpdate(cmd *cobra.Command, args []string) {
	fmt.Println(ui.Title("Actualizando ORGMOS"))
	fmt.Println(ui.Info(fmt.Sprintf("Ejecutando: curl -fsSL %s | sh", installURL)))
	fmt.Println()

	// Ejecutar curl | sh
	curlCmd := exec.Command("curl", "-fsSL", installURL)
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
		fmt.Println(ui.Error(fmt.Sprintf("Error en la actualización: %v", err)))
		return
	}
}

