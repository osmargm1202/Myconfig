package main

import (
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var assetsCmd = &cobra.Command{
	Use:   "assets",
	Short: "Copiar wallpapers",
	Long:  `Copia los wallpapers a ~/Pictures/Wallpapers`,
	Run:   runAssetsCopy,
}

func init() {
	rootCmd.AddCommand(assetsCmd)
}

func runAssetsCopy(cmd *cobra.Command, args []string) {
	logger.InitOnError("assets")

	fmt.Println(ui.Title("Copiar Wallpapers"))

	repoDir := utils.GetRepoDir()
	homeDir, _ := os.UserHomeDir()

	wallpapersSource := filepath.Join(repoDir, "Wallpapers")
	wallpapersDest := filepath.Join(homeDir, "Pictures", "Wallpapers")
	os.MkdirAll(wallpapersDest, 0o755)

	// Contar archivos
	var wallpaperCount int

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
				Title(fmt.Sprintf("Se copiarán %d wallpapers", wallpaperCount)).
				Description(fmt.Sprintf("Destino: %s", wallpapersDest)).
				Affirmative("Copiar").
				Negative("Cancelar").
				Value(&confirm),
		),
	)

	if err := form.Run(); err != nil || !confirm {
		fmt.Println(ui.Warning("Copia cancelada"))
		return
	}

	totalCopied := 0
	totalFailed := 0

	// Descargar wallpapers desde ML4W
	if remoteCopied, remoteFailed := downloadRemoteWallpapers(wallpapersDest); remoteCopied > 0 || remoteFailed > 0 {
		totalCopied += remoteCopied
		totalFailed += remoteFailed
		fmt.Println(ui.Success(fmt.Sprintf("Wallpapers ML4W copiados: %d", remoteCopied)))
		if remoteFailed > 0 {
			fmt.Println(ui.Warning(fmt.Sprintf("Fallidos (ML4W): %d archivos", remoteFailed)))
		}
	}

	// Copiar wallpapers locales del repositorio
	if wallpaperCount > 0 {
		fmt.Println(ui.Info("Copiando wallpapers locales..."))
		copied, failed := copyDirectory(wallpapersSource, wallpapersDest)
		totalCopied += copied
		totalFailed += failed
		fmt.Println(ui.Success(fmt.Sprintf("Wallpapers locales copiados: %d", copied)))
		if failed > 0 {
			fmt.Println(ui.Warning(fmt.Sprintf("Fallidos (locales): %d archivos", failed)))
		}
	} else {
		fmt.Println(ui.Warning("No se encontraron wallpapers locales en el repositorio"))
	}

	fmt.Println(ui.Success(fmt.Sprintf("Total wallpapers copiados: %d", totalCopied)))
	if totalFailed > 0 {
		fmt.Println(ui.Warning(fmt.Sprintf("Total fallidos: %d archivos", totalFailed)))
	}
	logger.Info("Wallpapers copiados: %d copiados, %d fallidos", totalCopied, totalFailed)
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

func downloadRemoteWallpapers(dest string) (copied, failed int) {
	fmt.Println(ui.Info("Descargando wallpapers desde ML4W..."))
	tempDir, err := os.MkdirTemp("", "wallpaper-clone-*")
	if err != nil {
		fmt.Println(ui.Warning("No se pudo crear carpeta temporal para wallpapers"))
		return 0, 0
	}
	defer os.RemoveAll(tempDir)

	repoURL := "https://github.com/mylinuxforwork/wallpaper.git"
	cloneCmd := exec.Command("git", "clone", "--depth=1", repoURL, tempDir)
	cloneCmd.Stdout = os.Stdout
	cloneCmd.Stderr = os.Stderr

	if err := cloneCmd.Run(); err != nil {
		fmt.Println(ui.Warning("No se pudo clonar el repositorio de wallpapers (ML4W)"))
		logger.Warn("Error clonando wallpapers ML4W: %v", err)
		return 0, 0
	}

	// Eliminar la carpeta .git antes de copiar
	os.RemoveAll(filepath.Join(tempDir, ".git"))

	fmt.Println(ui.Info("Copiando wallpapers descargados..."))
	return copyDirectory(tempDir, dest)
}
