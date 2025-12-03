package utils

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"orgmos/internal/logger"
	"orgmos/internal/ui"
)

// UpdateRepo actualiza el repositorio git
func UpdateRepo() error {
	repoDir := GetRepoDir()

	// Verificar si es un repositorio git
	gitDir := filepath.Join(repoDir, ".git")
	if _, err := os.Stat(gitDir); os.IsNotExist(err) {
		logger.Warn("No es un repositorio git: %s", repoDir)
		return nil
	}

	fmt.Println(ui.Info("Actualizando repositorio..."))

	// Cambiar al directorio del repo
	oldDir, _ := os.Getwd()
	if err := os.Chdir(repoDir); err != nil {
		return err
	}
	defer os.Chdir(oldDir)

	// Git pull
	output, err := RunCommandSilent("git", "pull", "--rebase")
	if err != nil {
		logger.Error("Error actualizando repo: %s", output)
		
		// Analizar el tipo de error
		outputLower := strings.ToLower(output)
		
		// Detectar errores de conexión
		if strings.Contains(outputLower, "could not resolve host") ||
			strings.Contains(outputLower, "connection refused") ||
			strings.Contains(outputLower, "failed to connect") ||
			strings.Contains(outputLower, "network is unreachable") ||
			strings.Contains(outputLower, "no route to host") ||
			strings.Contains(outputLower, "name or service not known") {
			fmt.Println(ui.Warning("No se pudo actualizar: sin conexión a internet"))
			return nil
		}
		
		// Detectar si ya está actualizado (a veces git devuelve error pero está actualizado)
		if strings.Contains(outputLower, "already up to date") ||
			strings.Contains(outputLower, "ya está actualizado") {
			fmt.Println(ui.Dim("Repositorio ya actualizado"))
			return nil
		}
		
		// Detectar conflictos o cambios locales que necesitan atención
		if strings.Contains(outputLower, "your local changes") ||
			strings.Contains(outputLower, "tus cambios locales") ||
			strings.Contains(outputLower, "cannot pull with rebase") ||
			strings.Contains(outputLower, "conflict") ||
			strings.Contains(outputLower, "unmerged paths") ||
			strings.Contains(outputLower, "needs merge") {
			fmt.Println(ui.Warning("No se pudo actualizar: hay cambios locales que necesitan ser actualizados primero"))
			fmt.Println(ui.Dim("Ejecuta 'git status' para ver los cambios y resuélvelos manualmente"))
			return nil
		}
		
		// Error genérico
		fmt.Println(ui.Warning("No se pudo actualizar el repositorio"))
		return nil // No es error fatal
	}

	// Verificar si ya estaba actualizado
	outputLower := strings.ToLower(output)
	if strings.Contains(outputLower, "already up to date") ||
		strings.Contains(outputLower, "ya está actualizado") ||
		output == "" {
		fmt.Println(ui.Dim("Repositorio ya actualizado"))
	} else {
		fmt.Println(ui.Success("Repositorio actualizado"))
		logger.Info("Repo actualizado: %s", output)
	}

	return nil

}

// CreateDesktopFile crea el archivo .desktop para orgmos
func CreateDesktopFile() error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	applicationsDir := filepath.Join(homeDir, ".local", "share", "applications")
	if err := os.MkdirAll(applicationsDir, 0755); err != nil {
		return err
	}

	desktopContent := `[Desktop Entry]
Name=ORGMOS
Comment=Sistema de configuración ORGMOS
Exec=orgmos menu
Terminal=true
Type=Application
Icon=orgmos
Categories=System;Utility;
Keywords=config;setup;system;
`

	desktopPath := filepath.Join(applicationsDir, "orgmos.desktop")
	if err := os.WriteFile(desktopPath, []byte(desktopContent), 0755); err != nil {
		logger.Error("Error creando desktop file: %v", err)
		return err
	}

	logger.Info("Desktop file creado: %s", desktopPath)
	return nil
}

// GetConfigRepoDir obtiene el directorio del repositorio para archivos de config
func GetConfigRepoDir() string {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(homeDir, ".config", "orgmos", "repo")
}

// DownloadConfigFiles descarga/actualiza el repositorio en ~/.config/orgmos/repo/
// para tener acceso a archivos de configuración sin necesidad del repo completo
func DownloadConfigFiles() error {
	configRepoDir := GetConfigRepoDir()
	if configRepoDir == "" {
		return fmt.Errorf("no se pudo obtener directorio de configuración")
	}

	repoURL := "https://github.com/osmargm1202/Myconfig.git"

	// Si el directorio no existe, clonar el repositorio
	if _, err := os.Stat(configRepoDir); os.IsNotExist(err) {
		fmt.Println(ui.Info("Clonando repositorio para archivos de configuración..."))
		logger.Info("Clonando repo en: %s", configRepoDir)

		// Crear directorio padre
		if err := os.MkdirAll(filepath.Dir(configRepoDir), 0755); err != nil {
			return fmt.Errorf("error creando directorio: %w", err)
		}

		// Clonar repositorio (solo como origen de lectura para las configs)
		output, err := RunCommandSilent("git", "clone", repoURL, configRepoDir)
		if err != nil {
			logger.Error("Error clonando repo: %s", output)
			return fmt.Errorf("error clonando repositorio: %w", err)
		}

		fmt.Println(ui.Success("Origen de archivos de configuración preparado"))
		logger.Info("Repo clonado exitosamente")
		return nil
	}

	// Si existe, actualizar (solo para mantener al día el origen de lectura)
	fmt.Println(ui.Info("Actualizando origen de archivos de configuración..."))
	logger.Info("Actualizando repo en: %s", configRepoDir)

	// Cambiar al directorio del repo
	oldDir, _ := os.Getwd()
	if err := os.Chdir(configRepoDir); err != nil {
		return fmt.Errorf("error cambiando a directorio del repo: %w", err)
	}
	defer os.Chdir(oldDir)

	// Git pull
	output, err := RunCommandSilent("git", "pull", "--rebase")
	if err != nil {
		logger.Warn("Error actualizando repo de config: %s", output)
		// No es error fatal, continuar con lo que hay
		fmt.Println(ui.Warning("No se pudo actualizar el repositorio de configuración"))
		return nil
	}

	// Verificar si ya estaba actualizado
	outputLower := strings.ToLower(output)
	if strings.Contains(outputLower, "already up to date") ||
		strings.Contains(outputLower, "ya está actualizado") ||
		output == "" {
		fmt.Println(ui.Dim("Origen de archivos de configuración ya actualizado"))
	} else {
		fmt.Println(ui.Success("Origen de archivos de configuración actualizado"))
		logger.Info("Repo de config actualizado: %s", output)
	}

	return nil
}

