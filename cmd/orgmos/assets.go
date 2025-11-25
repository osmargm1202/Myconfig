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

var assetsCmd = &cobra.Command{
	Use:   "assets",
	Short: "Copiar iconos y wallpapers",
	Long:  `Copia los iconos a ~/.local/share/icons y los wallpapers a ~/Pictures/Wallpapers`,
	Run:   runAssetsCopy,
}

func init() {
	rootCmd.AddCommand(assetsCmd)
}

func runAssetsCopy(cmd *cobra.Command, args []string) {
	logger.Init("assets")
	defer logger.Close()

	fmt.Println(ui.Title("Copiar Iconos y Wallpapers"))

	repoDir := utils.GetRepoDir()
	homeDir, _ := os.UserHomeDir()

	iconsSource := filepath.Join(repoDir, "Icons")
	wallpapersSource := filepath.Join(repoDir, "Wallpapers")

	iconsDest := filepath.Join(homeDir, ".local", "share", "icons")
	wallpapersDest := filepath.Join(homeDir, "Pictures", "Wallpapers")

	// Contar archivos
	var iconCount, wallpaperCount int

	if _, err := os.Stat(iconsSource); err == nil {
		filepath.WalkDir(iconsSource, func(path string, d fs.DirEntry, err error) error {
			if err == nil && !d.IsDir() {
				iconCount++
			}
			return nil
		})
	}

	if _, err := os.Stat(wallpapersSource); err == nil {
		filepath.WalkDir(wallpapersSource, func(path string, d fs.DirEntry, err error) error {
			if err == nil && !d.IsDir() {
				wallpaperCount++
			}
			return nil
		})
	}

	// Confirmación
	var confirm bool
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title(fmt.Sprintf("Se copiarán %d iconos y %d wallpapers", iconCount, wallpaperCount)).
				Description(fmt.Sprintf("Destinos:\n• Iconos: %s\n• Wallpapers: %s", iconsDest, wallpapersDest)).
				Affirmative("Copiar").
				Negative("Cancelar").
				Value(&confirm),
		),
	)

	if err := form.Run(); err != nil || !confirm {
		fmt.Println(ui.Warning("Copia cancelada"))
		return
	}

	var totalCopied, totalFailed int

	// Copiar iconos
	if iconCount > 0 {
		fmt.Println(ui.Info("Copiando iconos..."))
		copied, failed := copyDirectory(iconsSource, iconsDest)
		totalCopied += copied
		totalFailed += failed
		fmt.Println(ui.Success(fmt.Sprintf("Iconos copiados: %d", copied)))
	}

	// Copiar wallpapers
	if wallpaperCount > 0 {
		fmt.Println(ui.Info("Copiando wallpapers..."))
		copied, failed := copyDirectory(wallpapersSource, wallpapersDest)
		totalCopied += copied
		totalFailed += failed
		fmt.Println(ui.Success(fmt.Sprintf("Wallpapers copiados: %d", copied)))
	}

	fmt.Println(ui.Success(fmt.Sprintf("Total copiados: %d archivos", totalCopied)))
	if totalFailed > 0 {
		fmt.Println(ui.Warning(fmt.Sprintf("Fallidos: %d archivos", totalFailed)))
	}
	logger.Info("Assets copiados: %d copiados, %d fallidos", totalCopied, totalFailed)
}

func copyDirectory(src, dst string) (copied, failed int) {
	filepath.WalkDir(src, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}

		relPath, _ := filepath.Rel(src, path)
		destPath := filepath.Join(dst, relPath)

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
		return nil
	})

	return copied, failed
}

