package logger

import (
	"fmt"
	"os"
	"path/filepath"
	"time"
)

var (
	logFile   *os.File
	logDir    string
	isEnabled bool
)

// Init inicializa el sistema de logging
func Init(command string) error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	logDir = filepath.Join(homeDir, ".orgmoslog")
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return err
	}

	timestamp := time.Now().Format("2006-01-02_15-04-05")
	logPath := filepath.Join(logDir, fmt.Sprintf("orgmos-%s-%s.log", command, timestamp))

	logFile, err = os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return err
	}

	isEnabled = true
	Info("Log iniciado para comando: %s", command)
	return nil
}

// Close cierra el archivo de log
func Close() {
	if logFile != nil {
		logFile.Close()
	}
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

// Info registra mensaje informativo
func Info(format string, args ...interface{}) {
	write("INFO", format, args...)
}

// Warn registra advertencia
func Warn(format string, args ...interface{}) {
	write("WARN", format, args...)
}

// Error registra error
func Error(format string, args ...interface{}) {
	write("ERROR", format, args...)
}

// GetLogDir retorna el directorio de logs
func GetLogDir() string {
	return logDir
}

