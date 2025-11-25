package main

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Copiar configuraciones a ~/.config",
	Long:  `Copia todas las configuraciones del repositorio a ~/.config`,
	Run:   runConfigCopy,
}

func init() {
	rootCmd.AddCommand(configCmd)
}

func runConfigCopy(cmd *cobra.Command, args []string) {
	logger.Init("config")
	defer logger.Close()

	fmt.Println(ui.Title("Copiar Configuraciones"))

	repoDir := utils.GetRepoDir()
	// Buscar carpeta de configuraciones
	configSource := filepath.Join(repoDir, "configs_to_copy")
	if _, err := os.Stat(configSource); os.IsNotExist(err) {
		// Fallback a nombre anterior
		configSource = filepath.Join(repoDir, "folders to be copied to .config")
	}

	if _, err := os.Stat(configSource); os.IsNotExist(err) {
		fmt.Println(ui.Error("Carpeta de configuraciones no encontrada"))
		return
	}

	homeDir, _ := os.UserHomeDir()
	configDest := filepath.Join(homeDir, ".config")

	// Contar archivos
	var fileCount int
	filepath.WalkDir(configSource, func(path string, d fs.DirEntry, err error) error {
		if err == nil && !d.IsDir() {
			fileCount++
		}
		return nil
	})

	// Confirmación
	var confirm bool
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title(fmt.Sprintf("Se copiarán %d archivos a ~/.config", fileCount)).
				Description("Los archivos existentes serán sobrescritos").
				Affirmative("Copiar").
				Negative("Cancelar").
				Value(&confirm),
		),
	)

	if err := form.Run(); err != nil || !confirm {
		fmt.Println(ui.Warning("Copia cancelada"))
		return
	}

	// Copiar archivos
	fmt.Println(ui.Info("Copiando configuraciones..."))
	var copied, failed int

	err := filepath.WalkDir(configSource, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}

		relPath, _ := filepath.Rel(configSource, path)
		destPath := filepath.Join(configDest, relPath)

		if d.IsDir() {
			os.MkdirAll(destPath, 0755)
			return nil
		}

		// Copiar archivo
		data, err := os.ReadFile(path)
		if err != nil {
			logger.Error("Error leyendo %s: %v", path, err)
			failed++
			return nil
		}

		// Crear directorio padre si no existe
		os.MkdirAll(filepath.Dir(destPath), 0755)

		if err := os.WriteFile(destPath, data, 0644); err != nil {
			logger.Error("Error escribiendo %s: %v", destPath, err)
			failed++
			return nil
		}

		copied++
		logger.Info("Copiado: %s", relPath)
		return nil
	})

	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
		return
	}

	fmt.Println(ui.Success(fmt.Sprintf("Copiados: %d archivos", copied)))
	if failed > 0 {
		fmt.Println(ui.Warning(fmt.Sprintf("Fallidos: %d archivos", failed)))
	}
	logger.Info("Copia completada: %d copiados, %d fallidos", copied, failed)
}

