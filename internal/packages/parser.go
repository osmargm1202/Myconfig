package packages

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/BurntSushi/toml"

	"orgmos/internal/utils"
)

// PackageGroup representa un grupo de paquetes
type PackageGroup struct {
	Name     string
	Packages []string
}

// PackageConfig representa la configuración de paquetes TOML
type PackageConfig map[string]struct {
	Packages []string `toml:"packages"`
}

// ParseTOML lee un archivo TOML de paquetes
func ParseTOML(filename string) ([]PackageGroup, error) {
	repoDir := utils.GetRepoDir()
	filePath := filepath.Join(repoDir, "configs", filename)

	// Si no existe en configs, buscar en Apps (compatibilidad)
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		filePath = filepath.Join(repoDir, "Apps", filename)
	}

	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, err
	}

	var config PackageConfig
	if _, err := toml.Decode(string(data), &config); err != nil {
		return nil, err
	}

	var groups []PackageGroup
	for name, group := range config {
		// Limpiar nombres de paquetes (quitar comentarios)
		var cleanPkgs []string
		for _, pkg := range group.Packages {
			pkg = strings.TrimSpace(pkg)
			if pkg != "" && !strings.HasPrefix(pkg, "#") {
				// Quitar comentario inline
				if idx := strings.Index(pkg, "#"); idx > 0 {
					pkg = strings.TrimSpace(pkg[:idx])
				}
				cleanPkgs = append(cleanPkgs, pkg)
			}
		}

		if len(cleanPkgs) > 0 {
			groups = append(groups, PackageGroup{
				Name:     name,
				Packages: cleanPkgs,
			})
		}
	}

	return groups, nil
}

// GetAllPackages obtiene todos los paquetes de un archivo TOML
func GetAllPackages(filename string) ([]string, error) {
	groups, err := ParseTOML(filename)
	if err != nil {
		return nil, err
	}

	var all []string
	for _, g := range groups {
		all = append(all, g.Packages...)
	}

	return all, nil
}
