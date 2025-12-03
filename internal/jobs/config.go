package jobs

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// Config representa la configuración completa del sistema de jobs
type Config struct {
	HealthcheckBaseURL string                `yaml:"healthcheck_base_url"`
	DiscordWebhook     string                `yaml:"discord_webhook"`
	SyncTasks          map[string]SyncTask   `yaml:"sync_tasks"`
}

// SyncTask representa una tarea de sincronización
type SyncTask struct {
	Source         string   `yaml:"source"`
	Dest           string   `yaml:"dest"`
	HealthcheckID  string   `yaml:"healthcheck_id"`
	RsyncArgs      []string `yaml:"rsync_args"`
	CrontabSchedule string  `yaml:"crontab_schedule"` // Formato: "minuto hora día mes día_semana"
}

// GetConfigPath retorna la ruta al archivo de configuración
func GetConfigPath() (string, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("error obteniendo directorio home: %w", err)
	}
	return filepath.Join(homeDir, "orgmos", "config", "config.yaml"), nil
}

// LoadConfig carga la configuración desde el archivo YAML
func LoadConfig() (*Config, error) {
	configPath, err := GetConfigPath()
	if err != nil {
		return nil, err
	}

	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("error leyendo archivo de configuración %s: %w", configPath, err)
	}

	var config Config
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("error parseando YAML: %w", err)
	}

	// Validar que tenga valores mínimos
	if config.HealthcheckBaseURL == "" {
		config.HealthcheckBaseURL = "https://hc.or-gm.com"
	}

	return &config, nil
}

// GetSyncTask obtiene una tarea de sincronización por nombre
func (c *Config) GetSyncTask(name string) (*SyncTask, error) {
	task, exists := c.SyncTasks[name]
	if !exists {
		return nil, fmt.Errorf("tarea de sincronización '%s' no encontrada en la configuración", name)
	}

	// Validar que tenga los campos requeridos
	if task.Source == "" {
		return nil, fmt.Errorf("tarea '%s' no tiene 'source' definido", name)
	}
	if task.Dest == "" {
		return nil, fmt.Errorf("tarea '%s' no tiene 'dest' definido", name)
	}
	if task.HealthcheckID == "" {
		return nil, fmt.Errorf("tarea '%s' no tiene 'healthcheck_id' definido", name)
	}

	// Valores por defecto para rsync_args
	if len(task.RsyncArgs) == 0 {
		task.RsyncArgs = []string{"-avz", "-e", "ssh"}
	}

	return &task, nil
}

// GenerateCrontabLine genera la línea de crontab para una tarea
func (c *Config) GenerateCrontabLine(taskName string, task *SyncTask) (string, error) {
	if task.CrontabSchedule == "" {
		return "", fmt.Errorf("tarea '%s' no tiene 'crontab_schedule' definido", taskName)
	}

	// Obtener usuario actual
	user := os.Getenv("USER")
	if user == "" {
		user = "root"
	}

	// Obtener ruta del binario orgmos
	orgmosPath, err := os.Executable()
	if err != nil {
		// Fallback a comando en PATH
		orgmosPath = "orgmos"
	}

	// Generar línea de crontab
	// Formato: schedule user command
	crontabLine := fmt.Sprintf("%s %s %s jobs sync %s", 
		task.CrontabSchedule, 
		user, 
		orgmosPath, 
		taskName)

	return crontabLine, nil
}

