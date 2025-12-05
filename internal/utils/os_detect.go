package utils

import (
	"bufio"
	"os"
	"strings"
)

// DistroType representa el tipo de distribución Linux
type DistroType string

const (
	DistroArch    DistroType = "arch"
	DistroDebian  DistroType = "debian"
	DistroUbuntu  DistroType = "ubuntu"
	DistroUnknown DistroType = "unknown"
)

// DetectOS detecta el sistema operativo leyendo /etc/os-release
func DetectOS() DistroType {
	file, err := os.Open("/etc/os-release")
	if err != nil {
		return DistroUnknown
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	var id, idLike string

	for scanner.Scan() {
		line := scanner.Text()

		if strings.HasPrefix(line, "ID=") {
			id = strings.Trim(strings.TrimPrefix(line, "ID="), "\"")
		}
		if strings.HasPrefix(line, "ID_LIKE=") {
			idLike = strings.Trim(strings.TrimPrefix(line, "ID_LIKE="), "\"")
		}
	}

	// Normalizar a minúsculas
	id = strings.ToLower(id)
	idLike = strings.ToLower(idLike)

	// Detectar distribución
	switch id {
	case "arch", "manjaro", "endeavouros", "garuda", "artix":
		return DistroArch
	case "ubuntu", "linuxmint", "pop", "elementary", "zorin":
		return DistroUbuntu
	case "debian", "raspbian", "kali", "parrot":
		return DistroDebian
	}

	// Verificar ID_LIKE si no se detectó directamente
	if strings.Contains(idLike, "arch") {
		return DistroArch
	}
	if strings.Contains(idLike, "ubuntu") {
		return DistroUbuntu
	}
	if strings.Contains(idLike, "debian") {
		return DistroDebian
	}

	return DistroUnknown
}

// GetDistroID retorna el identificador de la distribución como string
func GetDistroID() string {
	return string(DetectOS())
}

// IsArch verifica si el sistema es Arch Linux o derivado
func IsArch() bool {
	return DetectOS() == DistroArch
}

// IsDebian verifica si el sistema es Debian o derivado (excluyendo Ubuntu)
func IsDebian() bool {
	return DetectOS() == DistroDebian
}

// IsUbuntu verifica si el sistema es Ubuntu o derivado
func IsUbuntu() bool {
	return DetectOS() == DistroUbuntu
}

// IsAptBased verifica si el sistema usa apt (Debian o Ubuntu)
func IsAptBased() bool {
	distro := DetectOS()
	return distro == DistroDebian || distro == DistroUbuntu
}

// GetDistroName retorna el nombre legible de la distribución
func GetDistroName() string {
	switch DetectOS() {
	case DistroArch:
		return "Arch Linux"
	case DistroDebian:
		return "Debian"
	case DistroUbuntu:
		return "Ubuntu"
	default:
		return "Unknown"
	}
}

// GetPackageManager retorna el gestor de paquetes de la distribución
func GetPackageManager() string {
	switch DetectOS() {
	case DistroArch:
		return "pacman"
	case DistroDebian, DistroUbuntu:
		return "apt"
	default:
		return "unknown"
	}
}

