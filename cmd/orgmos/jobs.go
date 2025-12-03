package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"orgmos/internal/jobs"
	"orgmos/internal/logger"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var jobsCmd = &cobra.Command{
	Use:   "jobs",
	Short: "Gestión de cronjobs y tareas automatizadas",
	Long:  `Gestiona tareas automatizadas como sincronizaciones rsync con healthchecks y logging.`,
}

var jobsInitCmd = &cobra.Command{
	Use:   "init",
	Short: "Inicializa la configuración de jobs",
	Long:  `Descarga el archivo de configuración base desde el repositorio y crea los directorios necesarios.`,
	Run:   runJobsInit,
}

var (
	crontabFlag bool
	dryRunFlag  bool
)

var jobsSyncCmd = &cobra.Command{
	Use:   "sync [task_name]",
	Short: "Ejecuta una tarea de sincronización",
	Long:  `Ejecuta una tarea de sincronización rsync definida en la configuración.`,
	Args:  cobra.ExactArgs(1),
	Run:   runJobsSync,
}

func init() {
	jobsSyncCmd.Flags().BoolVar(&crontabFlag, "crontab", false, "Muestra solo la línea de crontab para agregar al crontab del sistema")
	jobsSyncCmd.Flags().BoolVar(&dryRunFlag, "dry-run", false, "Ejecuta sin sincronizar realmente, solo verifica notificaciones")
	
	jobsCmd.AddCommand(jobsInitCmd)
	jobsCmd.AddCommand(jobsSyncCmd)
	rootCmd.AddCommand(jobsCmd)
}

func runJobsInit(cmd *cobra.Command, args []string) {
	logger.InitOnError("jobs-init")

	fmt.Println(ui.Title("Inicializar Jobs"))

	// Descargar/actualizar archivos de config si es necesario
	if err := utils.DownloadConfigFiles(); err != nil {
		fmt.Println(ui.Warning(fmt.Sprintf("No se pudieron descargar archivos de config: %v", err)))
		fmt.Println(ui.Info("Intentando usar repositorio local..."))
	}

	// Obtener directorio del repositorio
	repoDir := utils.GetConfigRepoDir()
	if repoDir == "" {
		repoDir = utils.GetRepoDir()
	}
	sourceYAML := filepath.Join(repoDir, "crontab", "config.yaml")

	// Verificar que el archivo fuente existe
	if _, err := os.Stat(sourceYAML); os.IsNotExist(err) {
		fmt.Println(ui.Error(fmt.Sprintf("Archivo de configuración no encontrado en: %s", sourceYAML)))
		fmt.Println(ui.Info("Asegúrate de que el repositorio esté actualizado"))
		return
	}

	// Obtener ruta de destino
	configPath, err := jobs.GetConfigPath()
	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
		return
	}

	// Crear directorios necesarios
	homeDir, _ := os.UserHomeDir()
	dirs := []string{
		filepath.Join(homeDir, "orgmos", "config"),
		filepath.Join(homeDir, "orgmos", "logs"),
		filepath.Join(homeDir, "orgmos", "locks"),
	}

	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0755); err != nil {
			fmt.Println(ui.Error(fmt.Sprintf("Error creando directorio %s: %v", dir, err)))
			return
		}
		fmt.Println(ui.Success(fmt.Sprintf("Directorio creado: %s", dir)))
	}

	// Leer archivo fuente
	data, err := os.ReadFile(sourceYAML)
	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error leyendo archivo fuente: %v", err)))
		return
	}

	// Escribir archivo de destino
	if err := os.WriteFile(configPath, data, 0644); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error escribiendo archivo de configuración: %v", err)))
		return
	}

	fmt.Println(ui.Success(fmt.Sprintf("Configuración copiada a: %s", configPath)))
	fmt.Println()
	fmt.Println(ui.Info("Próximos pasos:"))
	fmt.Println(ui.Dim("1. Edita el archivo de configuración con tus datos:"))
	fmt.Println(ui.Highlight(fmt.Sprintf("   %s", configPath)))
	fmt.Println(ui.Dim("2. Configura tus tareas de sincronización en la sección 'sync_tasks'"))
	fmt.Println(ui.Dim("3. Agrega tus healthcheck IDs correspondientes"))
	fmt.Println(ui.Dim("4. Ejecuta 'orgmos jobs sync <nombre_tarea>' para probar"))
}

func runJobsSync(cmd *cobra.Command, args []string) {
	taskName := args[0]
	
	// Si el flag --crontab está activo, solo mostrar la línea de crontab
	if crontabFlag {
		config, err := jobs.LoadConfig()
		if err != nil {
			fmt.Println(ui.Error(fmt.Sprintf("Error cargando configuración: %v", err)))
			fmt.Println(ui.Info("Ejecuta 'orgmos jobs init' para inicializar la configuración"))
			os.Exit(1)
		}

		task, err := config.GetSyncTask(taskName)
		if err != nil {
			fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
			os.Exit(1)
		}

		crontabLine, err := config.GenerateCrontabLine(taskName, task)
		if err != nil {
			fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
			os.Exit(1)
		}

		// Mostrar solo la línea de crontab
		fmt.Println(crontabLine)
		return
	}

	if err := logger.Init("jobs-sync"); err != nil {
		// Continuar aunque falle la inicialización del logger
		logger.InitOnError("jobs-sync")
	}

	if dryRunFlag {
		fmt.Println(ui.Title(fmt.Sprintf("Sincronización (DRY-RUN): %s", taskName)))
		fmt.Println(ui.Warning("Modo DRY-RUN: No se sincronizarán archivos, solo se verificarán las notificaciones"))
	} else {
		fmt.Println(ui.Title(fmt.Sprintf("Sincronización: %s", taskName)))
	}

	// Cargar configuración
	config, err := jobs.LoadConfig()
	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error cargando configuración: %v", err)))
		fmt.Println(ui.Info("Ejecuta 'orgmos jobs init' para inicializar la configuración"))
		return
	}

	// Obtener tarea
	task, err := config.GetSyncTask(taskName)
	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
		return
	}

	// Crear lock manager
	lockManager, err := jobs.NewLockManager()
	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error creando lock manager: %v", err)))
		return
	}

	// Crear healthcheck client
	healthcheckClient := jobs.NewHealthcheckClient(config.HealthcheckBaseURL)

	// Crear sync executor
	executor, err := jobs.NewSyncExecutor(lockManager, healthcheckClient)
	if err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error creando executor: %v", err)))
		return
	}

	// Ejecutar sincronización
	if err := executor.Execute(taskName, task, config, dryRunFlag); err != nil {
		fmt.Println(ui.Error(fmt.Sprintf("Error ejecutando sincronización: %v", err)))
		os.Exit(1)
	}

	if dryRunFlag {
		fmt.Println(ui.Success(fmt.Sprintf("DRY-RUN de '%s' completado exitosamente", taskName)))
	} else {
		fmt.Println(ui.Success(fmt.Sprintf("Sincronización '%s' completada exitosamente", taskName)))
	}
}

