package packages

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"

	"orgmos/internal/utils"
)

// ParseLST lee un archivo .lst de paquetes para una distribución específica
// El formato .lst es simple: un paquete por línea, comentarios con #, secciones con ===
func ParseLST(distro string, filename string) ([]PackageGroup, error) {
	dotfilesDir := utils.GetDotfilesDir()
	
	// Asegurar que el filename tenga extensión .lst
	if !strings.HasSuffix(filename, ".lst") {
		filename = filename + ".lst"
	}
	
	filePath := filepath.Join(dotfilesDir, "packages", distro, filename)

	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, err
	}

	var groups []PackageGroup
	var currentGroup *PackageGroup
	scanner := bufio.NewScanner(strings.NewReader(string(data)))

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		// Ignorar líneas vacías
		if line == "" {
			continue
		}

		// Ignorar líneas que son solo comentarios
		if strings.HasPrefix(line, "#") {
			// Verificar si es una sección (===)
			if strings.Contains(line, "===") {
				// Es una sección, crear nuevo grupo
				// Extraer nombre de sección (quitar # y ===)
				sectionName := strings.TrimSpace(line)
				sectionName = strings.TrimPrefix(sectionName, "#")
				sectionName = strings.TrimSpace(sectionName)
				sectionName = strings.Trim(sectionName, "=")
				sectionName = strings.TrimSpace(sectionName)

				// Si hay un grupo anterior con paquetes, agregarlo
				if currentGroup != nil && len(currentGroup.Packages) > 0 {
					groups = append(groups, *currentGroup)
				}

				// Crear nuevo grupo
				currentGroup = &PackageGroup{
					Name:     sectionName,
					Packages: []string{},
				}
			}
			// Si no es sección, es un comentario normal, ignorar
			continue
		}

		// Quitar comentarios inline (texto después de #)
		if idx := strings.Index(line, "#"); idx > 0 {
			line = strings.TrimSpace(line[:idx])
		}

		// Si la línea no está vacía después de quitar comentarios, es un paquete
		if line != "" {
			// Si no hay grupo actual, crear uno por defecto
			if currentGroup == nil {
				currentGroup = &PackageGroup{
					Name:     "Paquetes",
					Packages: []string{},
				}
			}
			currentGroup.Packages = append(currentGroup.Packages, line)
		}
	}

	// Agregar el último grupo si tiene paquetes
	if currentGroup != nil && len(currentGroup.Packages) > 0 {
		groups = append(groups, *currentGroup)
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}

	return groups, nil
}

// GetAllPackagesLST obtiene todos los paquetes de un archivo .lst para una distribución
func GetAllPackagesLST(distro string, filename string) ([]string, error) {
	groups, err := ParseLST(distro, filename)
	if err != nil {
		return nil, err
	}

	var all []string
	for _, g := range groups {
		all = append(all, g.Packages...)
	}

	return all, nil
}

