package utils

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/huh/spinner"

	"orgmos/internal/ui"
)

// UpdateRepo actualiza el repositorio git
func UpdateRepo() error {
	repoDir := GetRepoDir()

	// Verificar si es un repositorio git
	gitDir := filepath.Join(repoDir, ".git")
	if _, err := os.Stat(gitDir); os.IsNotExist(err) {
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
		return err
	}

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

		// Crear directorio padre
		if err := os.MkdirAll(filepath.Dir(configRepoDir), 0755); err != nil {
			return fmt.Errorf("error creando directorio: %w", err)
		}

		// Clonar repositorio
		output, err := RunCommandSilent("git", "clone", repoURL, configRepoDir)
		if err != nil {
			return fmt.Errorf("error clonando repositorio: %s - %w", output, err)
		}

		fmt.Println(ui.Success("Repositorio clonado para archivos de configuración"))
		return nil
	}

	// Si existe, actualizar
	fmt.Println(ui.Info("Actualizando repositorio de configuración..."))

	// Cambiar al directorio del repo
	oldDir, _ := os.Getwd()
	if err := os.Chdir(configRepoDir); err != nil {
		return fmt.Errorf("error cambiando a directorio del repo: %w", err)
	}
	defer os.Chdir(oldDir)

	// Git pull
	output, err := RunCommandSilent("git", "pull", "--rebase")
	if err != nil {
		// No es error fatal, continuar con lo que hay
		fmt.Println(ui.Warning("No se pudo actualizar el repositorio de configuración"))
		return nil
	}

	// Verificar si ya estaba actualizado
	outputLower := strings.ToLower(output)
	if strings.Contains(outputLower, "already up to date") ||
		strings.Contains(outputLower, "ya está actualizado") ||
		output == "" {
		fmt.Println(ui.Dim("Repositorio de configuración ya actualizado"))
	} else {
		fmt.Println(ui.Success("Repositorio de configuración actualizado"))
	}

	return nil
}

// GetDotfilesDir obtiene el directorio del repositorio dotfiles
func GetDotfilesDir() string {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(homeDir, "Downloads", "dotfiles")
}

// CloneOrUpdateDotfiles clona o actualiza el repositorio dotfiles en ~/Downloads/dotfiles
func CloneOrUpdateDotfiles() error {
	dotfilesDir := GetDotfilesDir()
	if dotfilesDir == "" {
		return fmt.Errorf("no se pudo obtener directorio de dotfiles")
	}

	repoURL := "https://github.com/osmargm1202/dotfiles.git"

	// Si el directorio no existe, clonar el repositorio
	if _, err := os.Stat(dotfilesDir); os.IsNotExist(err) {
		fmt.Println(ui.Info("Clonando repositorio dotfiles..."))

		// Crear directorio padre
		if err := os.MkdirAll(filepath.Dir(dotfilesDir), 0755); err != nil {
			return fmt.Errorf("error creando directorio: %w", err)
		}

		// Clonar repositorio
		output, err := RunCommandSilent("git", "clone", repoURL, dotfilesDir)
		if err != nil {
			fmt.Println(ui.Warning(fmt.Sprintf("No se pudo clonar el repositorio dotfiles: %s", output)))
			return fmt.Errorf("error clonando repositorio: %s - %w", output, err)
		}

		fmt.Println(ui.Success("Repositorio dotfiles clonado"))
		return nil
	}

	// Si existe, actualizar
	fmt.Println(ui.Info("Actualizando repositorio dotfiles..."))

	// Cambiar al directorio del repo
	oldDir, _ := os.Getwd()
	if err := os.Chdir(dotfilesDir); err != nil {
		fmt.Println(ui.Warning(fmt.Sprintf("No se pudo cambiar al directorio dotfiles: %v", err)))
		return fmt.Errorf("error cambiando a directorio del repo: %w", err)
	}
	defer os.Chdir(oldDir)

	// Verificar si es un repositorio git válido
	gitDir := filepath.Join(dotfilesDir, ".git")
	if _, err := os.Stat(gitDir); os.IsNotExist(err) {
		fmt.Println(ui.Warning("Directorio dotfiles existe pero no es un repositorio Git válido"))
		return fmt.Errorf("directorio no es un repositorio git válido")
	}

	// Git pull
	output, err := RunCommandSilent("git", "pull", "--rebase")
	if err != nil {
		// Analizar el tipo de error
		outputLower := strings.ToLower(output)

		// Detectar errores de conexión
		if strings.Contains(outputLower, "could not resolve host") ||
			strings.Contains(outputLower, "connection refused") ||
			strings.Contains(outputLower, "failed to connect") ||
			strings.Contains(outputLower, "network is unreachable") ||
			strings.Contains(outputLower, "no route to host") ||
			strings.Contains(outputLower, "name or service not known") {
			fmt.Println(ui.Warning("No se pudo actualizar dotfiles: sin conexión a internet"))
			return fmt.Errorf("sin conexión a internet")
		}

		// Detectar si ya está actualizado
		if strings.Contains(outputLower, "already up to date") ||
			strings.Contains(outputLower, "ya está actualizado") {
			fmt.Println(ui.Dim("Repositorio dotfiles ya actualizado"))
			return nil
		}

		// Detectar conflictos o cambios locales
		if strings.Contains(outputLower, "your local changes") ||
			strings.Contains(outputLower, "tus cambios locales") ||
			strings.Contains(outputLower, "cannot pull with rebase") ||
			strings.Contains(outputLower, "conflict") ||
			strings.Contains(outputLower, "unmerged paths") ||
			strings.Contains(outputLower, "needs merge") {
			fmt.Println(ui.Warning("No se pudo actualizar dotfiles: hay cambios locales"))
			return fmt.Errorf("cambios locales detectados")
		}

		// Error genérico
		fmt.Println(ui.Warning(fmt.Sprintf("No se pudo actualizar el repositorio dotfiles: %s", output)))
		return fmt.Errorf("error actualizando repositorio: %s", output)
	}

	// Verificar si ya estaba actualizado
	outputLower := strings.ToLower(output)
	if strings.Contains(outputLower, "already up to date") ||
		strings.Contains(outputLower, "ya está actualizado") ||
		output == "" {
		fmt.Println(ui.Dim("Repositorio dotfiles ya actualizado"))
	} else {
		fmt.Println(ui.Success("Repositorio dotfiles actualizado"))
	}

	return nil
}

// CloneOrUpdateDotfilesWithSpinner clona o actualiza el repositorio dotfiles con spinner de progreso
func CloneOrUpdateDotfilesWithSpinner() error {
	var cloneErr error

	spinner.New().
		Title("Clonando/actualizando repositorio dotfiles...").
		Action(func() {
			cloneErr = CloneOrUpdateDotfiles()
		}).
		Run()

	return cloneErr
}
