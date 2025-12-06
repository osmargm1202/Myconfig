package main

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/huh/spinner"
	"github.com/spf13/cobra"

	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var noConfirm bool

var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Copiar configuraciones a ~/.config",
	Long:  `Copia todas las configuraciones del repositorio a ~/.config`,
	Run:   runConfigCopy,
}

func init() {
	configCmd.Flags().BoolVar(&noConfirm, "no-confirm", false, "No pedir confirmación antes de copiar los archivos")
	rootCmd.AddCommand(configCmd)
}

func runConfigCopy(cmd *cobra.Command, args []string) {
	fmt.Println(ui.Title("Copiar Configuraciones"))

	// Clonar o actualizar repositorio dotfiles con spinner
	var cloneErr error
	spinner.New().
		Title("Clonando/actualizando repositorio dotfiles...").
		Action(func() {
			cloneErr = utils.CloneOrUpdateDotfiles()
		}).
		Run()

	if cloneErr != nil {
		fmt.Println(ui.Warning(fmt.Sprintf("No se pudo clonar/actualizar dotfiles: %v", cloneErr)))
		fmt.Println(ui.Warning("Se intentará copiar desde el directorio existente si está disponible"))
	}

	// Obtener directorio dotfiles
	dotfilesDir := utils.GetDotfilesDir()
	configSource := filepath.Join(dotfilesDir, "config")

	if _, err := os.Stat(configSource); os.IsNotExist(err) {
		fmt.Println(ui.Error("Carpeta de configuraciones no encontrada en ~/Downloads/dotfiles/config"))
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

	var copied, failed int
	var copyErr error

	// Copiar con spinner mostrando progreso
	spinner.New().
		Title("Copiando configuraciones...").
		Action(func() {
			copyErr = filepath.WalkDir(configSource, func(path string, d fs.DirEntry, err error) error {
				if err != nil {
					return nil
				}

				var relPath string
				relPath, _ = filepath.Rel(configSource, path)
				destPath := filepath.Join(configDest, relPath)

				if d.IsDir() {
					os.MkdirAll(destPath, 0755)
					return nil
				}

				// Copiar archivo
				data, err := os.ReadFile(path)
				if err != nil {
					failed++
					return nil
				}

				os.MkdirAll(filepath.Dir(destPath), 0755)

				if err := os.WriteFile(destPath, data, 0644); err != nil {
					failed++
					return nil
				}

				copied++
				return nil
			})
		}).
		Run()

	if copyErr != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", copyErr)))
		return
	}

	fmt.Println(ui.Success(fmt.Sprintf("Copiados: %d archivos", copied)))
	if failed > 0 {
		fmt.Println(ui.Warning(fmt.Sprintf("Fallidos: %d archivos", failed)))
	}
}
