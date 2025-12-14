package packages

import (
	"fmt"

	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

// InstallPacman instala paquetes con pacman
func InstallPacman(packages []string) error {
	if len(packages) == 0 {
		return nil
	}

	fmt.Println(ui.Info(fmt.Sprintf("Instalando %d paquetes con pacman...", len(packages))))

	args := append([]string{"-S", "--noconfirm", "--needed"}, packages...)
	return utils.RunCommandWithSudo("pacman", args...)
}

// InstallParu instala paquetes con paru (AUR)
func InstallParu(packages []string) error {
	if len(packages) == 0 {
		return nil
	}

	if !utils.CommandExists("paru") {
		fmt.Println(ui.Warning("paru no está instalado. Instálalo primero para paquetes AUR."))
		return nil
	}

	fmt.Println(ui.Info(fmt.Sprintf("Instalando %d paquetes AUR con paru...", len(packages))))

	args := append([]string{"-S", "--noconfirm", "--needed"}, packages...)
	return utils.RunCommand("paru", args...)
}

// InstallYay instala paquetes con yay (AUR)
func InstallYay(packages []string) error {
	if len(packages) == 0 {
		return nil
	}

	if !utils.CommandExists("yay") {
		fmt.Println(ui.Warning("yay no está instalado. Instálalo primero para paquetes AUR."))
		return nil
	}

	fmt.Println(ui.Info(fmt.Sprintf("Instalando %d paquetes AUR con yay...", len(packages))))

	args := append([]string{"-S", "--noconfirm", "--needed"}, packages...)
	return utils.RunCommand("yay", args...)
}

// InstallFlatpak instala aplicaciones Flatpak
func InstallFlatpak(packages []string) error {
	if len(packages) == 0 {
		return nil
	}

	if !utils.CommandExists("flatpak") {
		fmt.Println(ui.Warning("flatpak no está instalado"))
		return nil
	}

	fmt.Println(ui.Info(fmt.Sprintf("Instalando %d aplicaciones Flatpak...", len(packages))))

	args := append([]string{"install", "-y", "flathub"}, packages...)
	return utils.RunCommand("flatpak", args...)
}

// InstallApt instala paquetes con apt (Debian/Ubuntu)
func InstallApt(packages []string) error {
	if len(packages) == 0 {
		return nil
	}

	fmt.Println(ui.Info(fmt.Sprintf("Instalando %d paquetes con apt...", len(packages))))

	// Primero actualizar
	if err := utils.RunCommandWithSudo("apt", "update"); err != nil {
		return fmt.Errorf("error actualizando lista de paquetes: %w", err)
	}

	args := append([]string{"install", "-y"}, packages...)
	return utils.RunCommandWithSudo("apt", args...)
}

// InstallCategorized instala paquetes separados por categoría
func InstallCategorized(categories map[string][]string) error {
	// Instalar paquetes de repos oficiales primero
	if len(categories["pacman"]) > 0 {
		if err := InstallPacman(categories["pacman"]); err != nil {
			return err
		}
	}

	// Multilib
	if len(categories["multilib"]) > 0 {
		fmt.Println(ui.Warning("Se requiere multilib habilitado para algunos paquetes"))
		if err := InstallPacman(categories["multilib"]); err != nil {
			fmt.Println(ui.Warning(fmt.Sprintf("Error instalando multilib: %v", err)))
		}
	}

	// Chaotic-AUR
	if len(categories["chaotic"]) > 0 {
		fmt.Println(ui.Warning("Se requiere chaotic-aur para algunos paquetes"))
		if err := InstallPacman(categories["chaotic"]); err != nil {
			fmt.Println(ui.Warning(fmt.Sprintf("Error instalando chaotic: %v", err)))
		}
	}

	// AUR
	if len(categories["aur"]) > 0 {
		if err := InstallParu(categories["aur"]); err != nil {
			return err
		}
	}

	return nil
}

// InstallAllPackages instala todos los paquetes en una sola corrida usando el instalador especificado
// installer puede ser "pacman", "paru" o "yay"
// Si es paru o yay, instala todos los paquetes juntos (pueden manejar repos oficiales y AUR)
// Si es pacman, solo instala repos oficiales
func InstallAllPackages(installer string, packages []string) error {
	if len(packages) == 0 {
		return nil
	}

	fmt.Println(ui.Info(fmt.Sprintf("Instalando %d paquetes en una sola corrida con %s...", len(packages), installer)))

	// Si el instalador es paru o yay, puede instalar todo junto (repos oficiales + AUR)
	if installer == "paru" {
		if !utils.CommandExists("paru") {
			return fmt.Errorf("paru no está instalado")
		}
		args := append([]string{"-S", "--noconfirm", "--needed"}, packages...)
		return utils.RunCommand("paru", args...)
	} else if installer == "yay" {
		if !utils.CommandExists("yay") {
			return fmt.Errorf("yay no está instalado")
		}
		args := append([]string{"-S", "--noconfirm", "--needed"}, packages...)
		return utils.RunCommand("yay", args...)
	} else if installer == "pacman" {
		// Pacman solo puede instalar repos oficiales
		args := append([]string{"-S", "--noconfirm", "--needed"}, packages...)
		return utils.RunCommandWithSudo("pacman", args...)
	}

	return fmt.Errorf("instalador desconocido: %s", installer)
}
