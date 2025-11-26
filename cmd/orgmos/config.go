package main

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"time"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var (
	noConfirm   bool
	watch       bool
	delayRun    int
)

var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Copiar configuraciones a ~/.config",
	Long:  `Copia todas las configuraciones del repositorio a ~/.config`,
	Run:   runConfigCopy,
}

func init() {
	configCmd.Flags().BoolVar(&noConfirm, "no-confirm", false, "No pedir confirmación antes de copiar los archivos")
	configCmd.Flags().BoolVar(&watch, "watch", false, "Verifica cambios y copia automáticamente cuando ocurren")
	configCmd.Flags().IntVar(&delayRun, "delay-run", 0, "Retraso en segundos antes de copiar después de detectar cambios (solo con --watch)")
	rootCmd.AddCommand(configCmd)
}

func runConfigCopy(cmd *cobra.Command, args []string) {
	logger.InitOnError("config")

	printColorGum := func(msg string) {
		fmt.Println(ui.Title(msg))
	}

	copyFunc := func() {
		printColorGum("Copiar Configuraciones")

		repoDir := utils.GetRepoDir()
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
		confirm := noConfirm
		if !noConfirm {
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
		}

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

	if watch {
		// ------------ WATCH MODE ------------
		prevHash := ""
		delay := time.Duration(delayRun) * time.Second

		printColorGum(ui.Info("Modo watch: esperando cambios en configuraciones..."))
		for {
			repoDir := utils.GetRepoDir()
			configSource := filepath.Join(repoDir, "configs_to_copy")
			if _, err := os.Stat(configSource); os.IsNotExist(err) {
				configSource = filepath.Join(repoDir, "folders to be copied to .config")
			}

			// Simple hash con mtime + tamaño total
			hash := ""
			fileCount := 0
			filepath.WalkDir(configSource, func(path string, d fs.DirEntry, err error) error {
				if err == nil && !d.IsDir() {
					info, err := d.Info()
					if err == nil {
						hash += fmt.Sprintf("%s-%d|", info.ModTime(), info.Size())
						fileCount++
					}
				}
				return nil
			})

			// Si cambia hash, se copia (con delay opcional)
			if hash != prevHash {
				fmt.Print(ui.Info(fmt.Sprintf("Detectado cambio en configuraciones (%d archivos)!", fileCount)))
				if delay > 0 {
					fmt.Println(ui.Dim(fmt.Sprintf(" Esperando %ds antes de copiar...", delayRun)))
					time.Sleep(delay)
				} else {
					fmt.Println()
				}
				copyFunc()
				prevHash = hash
				fmt.Println(ui.Dim("Vigilando nuevos cambios..."))
			}
			time.Sleep(2 * time.Second)
		}
	} else {
		// ------------ NORMAL MODE ------------
		copyFunc()
	}
}

