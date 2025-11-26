package utils

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"orgmos/internal/logger"
	"orgmos/internal/ui"
)

// RunCommand ejecuta un comando y muestra la salida
func RunCommand(name string, args ...string) error {
	logger.Info("Ejecutando: %s %s", name, strings.Join(args, " "))

	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	err := cmd.Run()
	if err != nil {
		logger.Error("Error ejecutando %s: %v", name, err)
		return err
	}

	logger.Info("Comando completado: %s", name)
	return nil
}

// RunCommandSilent ejecuta un comando sin mostrar salida
func RunCommandSilent(name string, args ...string) (string, error) {
	logger.Info("Ejecutando (silencioso): %s %s", name, strings.Join(args, " "))

	cmd := exec.Command(name, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		logger.Error("Error: %s - %s", name, string(output))
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
// Si ninguno está disponible, escribe en logs
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

	// Si no hay sistema de notificaciones, solo loguear
	logger.Error("Dependencia faltante: %s (no se pudo notificar, swaync y notify-send no disponibles)", cmd)
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
	// Primero intenta encontrar el directorio desde el ejecutable
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
