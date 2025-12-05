package utils

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"orgmos/internal/ui"
)

// IsRoot verifica si el usuario actual es root
func IsRoot() bool {
	return os.Geteuid() == 0
}

// RunCommandWithSudo ejecuta un comando con sudo si no es root
func RunCommandWithSudo(name string, args ...string) error {
	if IsRoot() {
		// Si es root, ejecutar directamente
		return RunCommand(name, args...)
	}
	// Si no es root, usar sudo
	fullArgs := append([]string{name}, args...)
	return RunCommand("sudo", fullArgs...)
}

// RunCommand ejecuta un comando y muestra la salida
func RunCommand(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	err := cmd.Run()
	if err != nil {
		return err
	}

	return nil
}

// RunCommandSilent ejecuta un comando sin mostrar salida
func RunCommandSilent(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return string(output), err
	}

	return strings.TrimSpace(string(output)), nil
}

// RunCommandWithConfirm ejecuta un comando después de confirmación
func RunCommandWithConfirm(message string, name string, args ...string) error {
	fmt.Println(ui.Info(message))
	fmt.Print(ui.Highlight("¿Continuar? [Y/n]: "))

	reader := bufio.NewReader(os.Stdin)
	response, _ := reader.ReadString('\n')
	response = strings.TrimSpace(strings.ToLower(response))

	if response != "" && response != "y" && response != "yes" && response != "s" && response != "si" {
		fmt.Println(ui.Warning("Operación cancelada"))
		return nil
	}

	return RunCommand(name, args...)
}

// CommandExists verifica si un comando existe
func CommandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

// CheckDependency verifica si una dependencia existe y notifica si falta
func CheckDependency(cmd string) bool {
	return CommandExists(cmd)
}

// NotifyMissingDependency notifica que falta una dependencia usando swaync o notify-send
func NotifyMissingDependency(cmd string) {
	msg := fmt.Sprintf("Dependencia faltante: %s. Instálala con tu gestor de paquetes.", cmd)

	// Intentar con swaync-client primero
	if CommandExists("swaync-client") {
		exec.Command("swaync-client", "-t", msg).Run()
		return
	}

	// Fallback a notify-send
	if CommandExists("notify-send") {
		exec.Command("notify-send", "-u", "critical", "orgmos", msg).Run()
		return
	}

	// Si no hay sistema de notificaciones, imprimir en consola
	fmt.Println(ui.Warning(msg))
}

// RequireDependency verifica una dependencia y notifica si falta, retorna false si no existe
func RequireDependency(cmd string) bool {
	if CheckDependency(cmd) {
		return true
	}
	NotifyMissingDependency(cmd)
	return false
}

// GetRepoDir obtiene el directorio del repositorio
func GetRepoDir() string {
	// Primero intenta desde el directorio de trabajo actual
	cwd, err := os.Getwd()
	if err == nil {
		dir := cwd
		for i := 0; i < 5; i++ {
			if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
				return dir
			}
			dir = filepath.Dir(dir)
		}
	}

	// Intenta encontrar el directorio desde el ejecutable
	execPath, err := os.Executable()
	if err == nil {
		dir := filepath.Dir(execPath)
		for i := 0; i < 5; i++ {
			if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
				return dir
			}
			dir = filepath.Dir(dir)
		}
	}

	// Fallback a ubicación conocida
	homeDir, _ := os.UserHomeDir()
	return filepath.Join(homeDir, "Myconfig")
}
