package pkg

// Package representa un paquete de Arch Linux
type Package struct {
	Name        string // Nombre del paquete
	Version     string // Versión instalada o disponible
	Description string // Descripción del paquete
	Repository  string // Repositorio (core, extra, community, aur, etc.)
	Installed   bool   // Si está instalado o no
}

// String devuelve una representación en string del paquete
func (p Package) String() string {
	status := ""
	if p.Installed {
		status = "[instalado]"
	}
	repo := p.Repository
	if repo == "" {
		repo = "unknown"
	}
	return p.Name + " " + p.Version + " (" + repo + ") " + status
}



