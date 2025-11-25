package utils

import (
	"fmt"
	"os"
	"path/filepath"

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
		fmt.Println(ui.Warning("No se pudo actualizar el repositorio"))
		return nil // No es error fatal
	}

	if output == "Already up to date." || output == "Ya está actualizado." {
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

