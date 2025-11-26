package logger

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

var (
	logFile     *os.File
	logDir      string
	isEnabled   bool
	currentCmd  string
	initOnce    sync.Once
	initialized bool
)

// Init inicializa el sistema de logging (solo prepara, no crea archivo)
func Init(command string) error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	logDir = filepath.Join(homeDir, ".orgmoslog")
	currentCmd = command
	// No crear archivo aún, solo preparar
	return nil
}

// initLogFile crea el archivo de log cuando realmente se necesita
func initLogFile() error {
	if initialized {
		return nil
	}

	if logDir == "" {
		homeDir, _ := os.UserHomeDir()
		logDir = filepath.Join(homeDir, ".orgmoslog")
	}

	if err := os.MkdirAll(logDir, 0755); err != nil {
		return err
	}

	cmd := currentCmd
	if cmd == "" {
		cmd = "orgmos"
	}

	timestamp := time.Now().Format("2006-01-02_15-04-05")
	logPath := filepath.Join(logDir, fmt.Sprintf("orgmos-%s-%s.log", cmd, timestamp))

	var err error
	logFile, err = os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return err
	}

	isEnabled = true
	initialized = true
	return nil
}

// Close cierra el archivo de log
func Close() {
	if logFile != nil {
		logFile.Close()
		logFile = nil
	}
	initialized = false
	isEnabled = false
}

// write escribe al archivo de log
func write(level, format string, args ...interface{}) {
	if !isEnabled || logFile == nil {
		return
	}

	timestamp := time.Now().Format("2006-01-02 15:04:05")
	message := fmt.Sprintf(format, args...)
	fmt.Fprintf(logFile, "[%s] [%s] %s\n", timestamp, level, message)
}

// Info registra mensaje informativo (solo si el log ya está inicializado)
func Info(format string, args ...interface{}) {
	// Info no inicializa el log automáticamente
	write("INFO", format, args...)
}

// Warn registra advertencia (inicializa log si es necesario)
func Warn(format string, args ...interface{}) {
	if !initialized {
		initLogFile()
	}
	write("WARN", format, args...)
}

// Error registra error (inicializa log si es necesario)
func Error(format string, args ...interface{}) {
	if !initialized {
		initLogFile()
	}
	write("ERROR", format, args...)
}

// GetLogDir retorna el directorio de logs
func GetLogDir() string {
	return logDir
}

// InitOnError inicializa el log solo cuando hay un error
// Usar esto en lugar de Init() cuando solo quieres log en errores
func InitOnError(command string) {
	homeDir, _ := os.UserHomeDir()
	logDir = filepath.Join(homeDir, ".orgmoslog")
	currentCmd = command
}
