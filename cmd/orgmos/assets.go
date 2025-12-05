package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/ui"
)

var assetsCmd = &cobra.Command{
	Use:   "assets",
	Short: "Descargar wallpapers",
	Long:  `Clona el repositorio de wallpapers a ~/Pictures/Wallpapers`,
	Run:   runAssetsCopy,
}

func init() {
	rootCmd.AddCommand(assetsCmd)
}

func runAssetsCopy(cmd *cobra.Command, args []string) {
	fmt.Println(ui.Title("Descargar Wallpapers"))

	homeDir, _ := os.UserHomeDir()
	wallpapersDest := filepath.Join(homeDir, "Pictures", "Wallpapers")

	// Confirmación
	var confirm bool
	form := ui.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title("Descargar wallpapers").
				Description(fmt.Sprintf("Se clonará el repositorio de wallpapers en:\n%s", wallpapersDest)).
				Affirmative("Descargar").
				Negative("Cancelar").
				Value(&confirm),
		),
	)

	if err := form.Run(); err != nil || !confirm {
		fmt.Println(ui.Warning("Descarga cancelada"))
		return
	}

	// Crear directorio Pictures si no existe
	os.MkdirAll(filepath.Join(homeDir, "Pictures"), 0755)

	repoURL := "https://github.com/osmargm1202/wallpapers.git"

	// Si ya existe el directorio, hacer pull
	if _, err := os.Stat(wallpapersDest); err == nil {
		fmt.Println(ui.Info("Repositorio existente, actualizando..."))
		
		pullCmd := exec.Command("git", "-C", wallpapersDest, "pull", "--ff-only")
		pullCmd.Stdout = os.Stdout
		pullCmd.Stderr = os.Stderr

		if err := pullCmd.Run(); err != nil {
			fmt.Println(ui.Warning("No se pudo actualizar. Intentando clonar de nuevo..."))
			os.RemoveAll(wallpapersDest)
		} else {
			fmt.Println(ui.Success("Wallpapers actualizados correctamente"))
			return
		}
	}

	// Clonar repositorio
	fmt.Println(ui.Info("Clonando repositorio de wallpapers..."))
	cloneCmd := exec.Command("git", "clone", "--depth=1", repoURL, wallpapersDest)
	cloneCmd.Stdout = os.Stdout
	cloneCmd.Stderr = os.Stderr

	if err := cloneCmd.Run(); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error clonando wallpapers: %v", err)))
		return
	}

	fmt.Println(ui.Success("Wallpapers descargados correctamente"))
}
