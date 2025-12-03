package jobs

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// LockManager maneja los archivos de lock para prevenir ejecuciones duplicadas
type LockManager struct {
	lockDir string
}

// NewLockManager crea un nuevo gestor de locks
func NewLockManager() (*LockManager, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("error obteniendo directorio home: %w", err)
	}

	lockDir := filepath.Join(homeDir, "orgmos", "locks")
	if err := os.MkdirAll(lockDir, 0755); err != nil {
		return nil, fmt.Errorf("error creando directorio de locks: %w", err)
	}

	return &LockManager{lockDir: lockDir}, nil
}

// LockPath retorna la ruta del archivo de lock para una tarea
func (lm *LockManager) LockPath(taskName string) string {
	return filepath.Join(lm.lockDir, fmt.Sprintf("sync-%s.lock", taskName))
}

// TryLock intenta adquirir un lock. Retorna error si ya existe un lock válido
func (lm *LockManager) TryLock(taskName string) error {
	lockPath := lm.LockPath(taskName)

	// Verificar si el lock existe
	if _, err := os.Stat(lockPath); err == nil {
		// Lock existe, verificar si el proceso sigue vivo
		data, err := os.ReadFile(lockPath)
		if err != nil {
			// Si no podemos leer el lock, asumimos que está corrupto y lo eliminamos
			os.Remove(lockPath)
		} else {
			// Parsear PID del lock
			parts := strings.Fields(string(data))
			if len(parts) > 0 {
				pid, err := strconv.Atoi(parts[0])
				if err == nil {
					// Verificar si el proceso existe
					if processExists(pid) {
						return fmt.Errorf("ya existe una ejecución en curso (PID: %d). Lock file: %s", pid, lockPath)
					}
					// Proceso no existe, lock huérfano, lo eliminamos
				}
			}
			os.Remove(lockPath)
		}
	}

	// Crear nuevo lock
	pid := os.Getpid()
	timestamp := time.Now().Unix()
	lockContent := fmt.Sprintf("%d %d\n", pid, timestamp)
	if err := os.WriteFile(lockPath, []byte(lockContent), 0644); err != nil {
		return fmt.Errorf("error creando lock file: %w", err)
	}

	return nil
}

// Unlock elimina el archivo de lock
func (lm *LockManager) Unlock(taskName string) error {
	lockPath := lm.LockPath(taskName)
	if err := os.Remove(lockPath); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("error eliminando lock file: %w", err)
	}
	return nil
}

// processExists verifica si un proceso con el PID dado existe
func processExists(pid int) bool {
	process, err := os.FindProcess(pid)
	if err != nil {
		return false
	}

	// Enviar señal 0 para verificar si el proceso existe sin matarlo
	err = process.Signal(syscall.Signal(0))
	return err == nil
}

