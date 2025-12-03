package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var proyectoCmd = &cobra.Command{
	Use:   "proyecto",
	Short: "Crear nuevo proyecto con estructura de carpetas",
	Long:  `Crea un nuevo proyecto en ~/Nextcloud/Proyectos/ con la estructura de carpetas estándar.`,
	Run:   runProyecto,
}

func init() {
	rootCmd.AddCommand(proyectoCmd)
}

func runProyecto(cmd *cobra.Command, args []string) {
	logger.InitOnError("proyecto")

	fmt.Println(ui.Title("Crear Nuevo Proyecto"))

	// Verificar que gum esté disponible
	if !utils.CommandExists("gum") {
		fmt.Println(ui.Error("gum no está instalado. Instala con: paru -S gum"))
		return
	}

	// Pedir nombre de la carpeta madre usando gum
	nombreCmd := exec.Command("gum", "input", "--placeholder", "Nombre de la carpeta madre")
	nombreCmd.Stderr = os.Stderr
	nombreBytes, err := nombreCmd.Output()
	if err != nil {
		// Si el usuario cancela (Ctrl+C), returncode será 130
		if exitError, ok := err.(*exec.ExitError); ok && exitError.ExitCode() == 130 {
			fmt.Println(ui.Warning("Operación cancelada"))
			return
		}
		fmt.Println(ui.Error(fmt.Sprintf("Error obteniendo nombre: %v", err)))
		return
	}

	nombreMadre := strings.TrimSpace(string(nombreBytes))
	if nombreMadre == "" {
		fmt.Println(ui.Error("El nombre no puede estar vacío"))
		return
	}

	// Obtener directorio home
	homeDir, err := os.UserHomeDir()
	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error obteniendo directorio home: %v", err)))
		return
	}

	// Crear ruta completa del proyecto
	proyectoDir := filepath.Join(homeDir, "Nextcloud", "Proyectos", nombreMadre)

	// Verificar si ya existe
	if _, err := os.Stat(proyectoDir); err == nil {
		fmt.Println(ui.Warning(fmt.Sprintf("El proyecto '%s' ya existe en %s", nombreMadre, proyectoDir)))
		return
	}

	// Crear carpeta madre
	if err := os.MkdirAll(proyectoDir, 0755); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error creando carpeta madre: %v", err)))
		return
	}

	// Crear subcarpetas
	subcarpetas := []string{
		"Comunicacion",
		"Diseño",
		"Estudios",
		"Calculos",
		"Levantamientos",
		"Entregas",
		"Recibido",
		"Oferta",
	}

	for _, subcarpeta := range subcarpetas {
		subcarpetaPath := filepath.Join(proyectoDir, subcarpeta)
		if err := os.MkdirAll(subcarpetaPath, 0755); err != nil {
			fmt.Println(ui.Error(fmt.Sprintf("Error creando subcarpeta '%s': %v", subcarpeta, err)))
			return
		}
	}

	fmt.Println(ui.Success(fmt.Sprintf("Proyecto '%s' creado con éxito en %s", nombreMadre, proyectoDir)))
	fmt.Println(ui.Info(fmt.Sprintf("Subcarpetas creadas: %s", strings.Join(subcarpetas, ", "))))
}

