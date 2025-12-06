package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/spf13/cobra"

	"orgmos/internal/ui"
)

const binURL = "https://custom.or-gm.com/orgmos"
const installScriptURL = "https://custom.or-gm.com/orgmos.sh"

var updateCmd = &cobra.Command{
	Use:   "update",
	Short: "Actualizar ORGMOS",
	Long:  `Descarga y actualiza el binario de ORGMOS a la última versión.`,
	Run:   runUpdate,
}

func init() {
	rootCmd.AddCommand(updateCmd)
}

func runUpdate(cmd *cobra.Command, args []string) {
	fmt.Println(ui.Title("Actualizando ORGMOS"))

	homeDir, err := os.UserHomeDir()
	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error obteniendo directorio home: %v", err)))
		return
	}

	binPath := filepath.Join(homeDir, ".local", "bin", "orgmos")
	tmpBinPath := "/tmp/orgmos_update"

	// Verificar si el binario existe
	if _, err := os.Stat(binPath); os.IsNotExist(err) {
		fmt.Println(ui.Warning("Binario orgmos no encontrado. Ejecuta el script de instalación:"))
		fmt.Println(ui.Info(fmt.Sprintf("curl -fsSL %s | sh", installScriptURL)))
		return
	}

	// Intentar detectar si el binario está en uso
	// Intentamos renombrar temporalmente para verificar si está bloqueado
	testPath := binPath + ".test"
	renameErr := os.Rename(binPath, testPath)
	binInUse := false

	if renameErr != nil {
		// No se pudo renombrar, probablemente está en uso
		binInUse = true
	} else {
		// Se pudo renombrar, restaurar
		os.Rename(testPath, binPath)
	}

	if binInUse {
		// Binario en uso, descargar a /tmp y mostrar instrucciones
		fmt.Println(ui.Warning("El binario orgmos está en uso y no puede ser reemplazado automáticamente."))
		fmt.Println(ui.Info("Descargando nueva versión a /tmp/orgmos_update..."))

		// Descargar a /tmp
		var downloadCmd *exec.Cmd
		if _, err := exec.LookPath("curl"); err == nil {
			downloadCmd = exec.Command("curl", "-fsSL", binURL, "-o", tmpBinPath)
		} else if _, err := exec.LookPath("wget"); err == nil {
			downloadCmd = exec.Command("wget", "-q", binURL, "-O", tmpBinPath)
		} else {
			fmt.Println(ui.Error("Se requiere curl o wget para descargar el binario"))
			return
		}

		if err := downloadCmd.Run(); err != nil {
			fmt.Println(ui.Error(fmt.Sprintf("Error descargando binario: %v", err)))
			return
		}

		// Hacer ejecutable
		os.Chmod(tmpBinPath, 0755)

		fmt.Println(ui.Success("Binario descargado a /tmp/orgmos_update"))
		fmt.Println()
		fmt.Println(ui.Info("Para completar la actualización:"))
		fmt.Println(ui.Dim("1. Cierra todas las instancias de orgmos"))
		fmt.Println(ui.Dim(fmt.Sprintf("2. Ejecuta: mv %s %s", tmpBinPath, binPath)))
		fmt.Println()
		fmt.Println(ui.Info("O descarga manualmente desde:"))
		fmt.Println(ui.Dim(binURL))
	} else {
		// Binario no en uso, reemplazar directamente
		fmt.Println(ui.Info("Descargando nueva versión..."))

		// Descargar a /tmp primero
		var downloadCmd *exec.Cmd
		if _, err := exec.LookPath("curl"); err == nil {
			downloadCmd = exec.Command("curl", "-fsSL", binURL, "-o", tmpBinPath)
		} else if _, err := exec.LookPath("wget"); err == nil {
			downloadCmd = exec.Command("wget", "-q", binURL, "-O", tmpBinPath)
		} else {
			fmt.Println(ui.Error("Se requiere curl o wget para descargar el binario"))
			return
		}

		if err := downloadCmd.Run(); err != nil {
			fmt.Println(ui.Error(fmt.Sprintf("Error descargando binario: %v", err)))
			return
		}

		// Hacer ejecutable
		os.Chmod(tmpBinPath, 0755)

		// Reemplazar binario
		if err := os.Rename(tmpBinPath, binPath); err != nil {
			fmt.Println(ui.Error(fmt.Sprintf("Error reemplazando binario: %v", err)))
			fmt.Println(ui.Info("El binario descargado está en /tmp/orgmos_update"))
			return
		}

		fmt.Println(ui.Success("ORGMOS actualizado correctamente"))
	}
}

