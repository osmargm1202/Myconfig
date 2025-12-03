package jobs

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"orgmos/internal/logger"
)

// SyncExecutor ejecuta tareas de sincronización rsync
type SyncExecutor struct {
	lockManager      *LockManager
	healthcheckClient *HealthcheckClient
	logDir           string
}

// NewSyncExecutor crea un nuevo ejecutor de sincronización
func NewSyncExecutor(lockManager *LockManager, healthcheckClient *HealthcheckClient) (*SyncExecutor, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("error obteniendo directorio home: %w", err)
	}

	logDir := filepath.Join(homeDir, "orgmos", "logs")
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return nil, fmt.Errorf("error creando directorio de logs: %w", err)
	}

	return &SyncExecutor{
		lockManager:       lockManager,
		healthcheckClient: healthcheckClient,
		logDir:            logDir,
	}, nil
}

// Execute ejecuta una tarea de sincronización
func (se *SyncExecutor) Execute(taskName string, task *SyncTask, config *Config, dryRun bool) error {
	logger.Info("Iniciando sincronización: %s", taskName)
	logger.Info("Source: %s", task.Source)
	logger.Info("Dest: %s", task.Dest)

	// Intentar adquirir lock
	if err := se.lockManager.TryLock(taskName); err != nil {
		return fmt.Errorf("no se pudo adquirir lock: %w", err)
	}
	defer se.lockManager.Unlock(taskName)

	// Crear archivo de log
	timestamp := time.Now().Format("2006-01-02_15-04-05")
	logFile := filepath.Join(se.logDir, fmt.Sprintf("sync-%s-%s.log", taskName, timestamp))
	
	logFileHandle, err := os.Create(logFile)
	if err != nil {
		logger.Error("Error creando archivo de log: %v", err)
		// Continuar sin archivo de log si no se puede crear
		logFileHandle = nil
	} else {
		defer logFileHandle.Close()
		logger.Info("Log guardado en: %s", logFile)
	}

	// Función helper para escribir en log
	writeLog := func(format string, args ...interface{}) {
		msg := fmt.Sprintf(format, args...)
		if logFileHandle != nil {
			timestamp := time.Now().Format("2006-01-02 15:04:05")
			fmt.Fprintf(logFileHandle, "[%s] %s\n", timestamp, msg)
		}
		logger.Info(msg)
	}

	writeLog("=== Inicio de sincronización: %s ===", taskName)
	writeLog("Source: %s", task.Source)
	writeLog("Dest: %s", task.Dest)

	// Verificar que el directorio destino exista o pueda crearse
	// Si el destino termina en /, es un directorio; si no, creamos el directorio padre
	destPath := task.Dest
	if strings.HasSuffix(destPath, "/") {
		// Es un directorio, crear el directorio mismo
		if err := os.MkdirAll(destPath, 0755); err != nil {
			writeLog("ERROR: No se pudo crear directorio destino: %v", err)
			se.healthcheckClient.PingFail(task.HealthcheckID)
			return fmt.Errorf("error creando directorio destino: %w", err)
		}
	} else {
		// Puede ser un archivo o directorio, crear el directorio padre
		destDir := filepath.Dir(destPath)
		if err := os.MkdirAll(destDir, 0755); err != nil {
			writeLog("ERROR: No se pudo crear directorio destino: %v", err)
			se.healthcheckClient.PingFail(task.HealthcheckID)
			return fmt.Errorf("error creando directorio destino: %w", err)
		}
	}

	// Enviar healthcheck de inicio
	if err := se.healthcheckClient.PingStart(task.HealthcheckID); err != nil {
		writeLog("ADVERTENCIA: No se pudo enviar healthcheck de inicio: %v", err)
		// No fallar si el healthcheck falla
	}

	// Construir comando rsync
	args := append(task.RsyncArgs, task.Source, task.Dest)
	
	if dryRun {
		writeLog("DRY-RUN: No se ejecutará rsync realmente")
		writeLog("DRY-RUN: Comando que se ejecutaría: rsync %v", args)
		writeLog("DRY-RUN: Simulando ejecución exitosa...")
		// En dry-run, solo verificamos las notificaciones
		time.Sleep(500 * time.Millisecond) // Pequeña pausa para simular
		writeLog("DRY-RUN: ✓ Simulación completada")
		writeLog("=== Fin de sincronización (DRY-RUN): %s ===", taskName)
		
		// Enviar healthcheck de éxito para verificar que funciona
		if err := se.healthcheckClient.Ping(task.HealthcheckID); err != nil {
			writeLog("ADVERTENCIA: No se pudo enviar healthcheck de éxito: %v", err)
		}
		return nil
	}

	writeLog("Ejecutando: rsync %v", args)

	cmd := exec.Command("rsync", args...)
	
	// Redirigir salida al log y a stdout
	if logFileHandle != nil {
		cmd.Stdout = logFileHandle
		cmd.Stderr = logFileHandle
	} else {
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
	}

	// Ejecutar rsync
	startTime := time.Now()
	err = cmd.Run()
	duration := time.Since(startTime)

	if err != nil {
		writeLog("ERROR: rsync falló después de %v: %v", duration, err)
		se.healthcheckClient.PingFail(task.HealthcheckID)
		return fmt.Errorf("rsync falló: %w", err)
	}

	writeLog("✓ Sincronización completada exitosamente en %v", duration)
	writeLog("=== Fin de sincronización: %s ===", taskName)

	// Enviar healthcheck de éxito
	if err := se.healthcheckClient.Ping(task.HealthcheckID); err != nil {
		writeLog("ADVERTENCIA: No se pudo enviar healthcheck de éxito: %v", err)
		// No fallar si el healthcheck falla
	}

	return nil
}

