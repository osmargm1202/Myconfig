package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"orgmos/internal/ui"
)

var installCmd = &cobra.Command{
	Use:   "install",
	Short: "Instalar ORGMOS en el sistema",
	Long:  `Crea el archivo .desktop para acceder a ORGMOS desde el menú de aplicaciones.`,
	Run:   runInstall,
}

func init() {
	rootCmd.AddCommand(installCmd)
}

func runInstall(cmd *cobra.Command, args []string) {
	fmt.Println(ui.Title("Instalación de ORGMOS"))

	homeDir, err := os.UserHomeDir()
	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error obteniendo directorio home: %v", err)))
		return
	}

	// Crear directorio de aplicaciones si no existe
	applicationsDir := filepath.Join(homeDir, ".local", "share", "applications")
	if err := os.MkdirAll(applicationsDir, 0755); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error creando directorio: %v", err)))
		return
	}

	// Obtener ruta del ejecutable
	execPath, err := os.Executable()
	if err != nil {
		execPath = "orgmos" // Fallback al nombre del comando
	}

	// Contenido del archivo .desktop
	desktopContent := fmt.Sprintf(`[Desktop Entry]
Name=ORGMOS
Comment=Sistema de configuración ORGMOS - Menú interactivo
GenericName=System Configuration
Exec=%s menu
Terminal=true
Type=Application
Icon=utilities-terminal
Categories=System;Utility;Settings;
Keywords=config;setup;system;orgmos;arch;debian;ubuntu;
StartupNotify=false
`, execPath)

	// Escribir archivo .desktop
	desktopPath := filepath.Join(applicationsDir, "orgmos.desktop")
	if err := os.WriteFile(desktopPath, []byte(desktopContent), 0755); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error escribiendo archivo desktop: %v", err)))
		return
	}

	fmt.Println(ui.Success("Archivo .desktop creado exitosamente"))
	fmt.Println(ui.Info(fmt.Sprintf("Ubicación: %s", desktopPath)))
	fmt.Println()
	fmt.Println(ui.Dim("Ahora puedes acceder a ORGMOS desde el menú de aplicaciones."))
	fmt.Println(ui.Dim("También puedes ejecutarlo con: orgmos menu"))
}

