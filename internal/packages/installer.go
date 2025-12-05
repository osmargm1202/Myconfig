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
	return utils.RunCommand("sudo", append([]string{"pacman"}, args...)...)
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

// InstallApt instala paquetes con apt (Ubuntu)
func InstallApt(packages []string) error {
	if len(packages) == 0 {
		return nil
	}

	fmt.Println(ui.Info(fmt.Sprintf("Instalando %d paquetes con apt...", len(packages))))

	// Primero actualizar
	utils.RunCommand("sudo", "apt", "update")

	args := append([]string{"apt", "install", "-y"}, packages...)
	return utils.RunCommand("sudo", args...)
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
