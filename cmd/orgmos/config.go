package main

import (
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/charmbracelet/huh"
	"github.com/spf13/cobra"

	"orgmos/internal/logger"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var (
	noConfirm   bool
	watch       bool
	delayRun    int
)

var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Copiar configuraciones a ~/.config",
	Long:  `Copia todas las configuraciones del repositorio a ~/.config`,
	Run:   runConfigCopy,
}

func init() {
	configCmd.Flags().BoolVar(&noConfirm, "no-confirm", false, "No pedir confirmación antes de copiar los archivos")
	configCmd.Flags().BoolVar(&watch, "watch", false, "Verifica cambios y copia automáticamente cuando ocurren")
	configCmd.Flags().IntVar(&delayRun, "delay-run", 0, "Retraso en segundos antes de copiar después de detectar cambios (solo con --watch)")
	rootCmd.AddCommand(configCmd)
}

func runConfigCopy(cmd *cobra.Command, args []string) {
	logger.InitOnError("config")

	printColorGum := func(msg string) {
		fmt.Println(ui.Title(msg))
	}

	copyFunc := func() {
		printColorGum("Copiar Configuraciones")

		// Descargar/actualizar archivos de config si es necesario
		if err := utils.DownloadConfigFiles(); err != nil {
			fmt.Println(ui.Warning(fmt.Sprintf("No se pudieron descargar archivos de config: %v", err)))
			fmt.Println(ui.Info("Intentando usar repositorio local..."))
		}

		repoDir := utils.GetConfigRepoDir()
		if repoDir == "" {
			// Fallback al repo local si no hay config repo
			repoDir = utils.GetRepoDir()
		}
		configSource := filepath.Join(repoDir, "configs_to_copy")
		if _, err := os.Stat(configSource); os.IsNotExist(err) {
			// Fallback a nombre anterior
			configSource = filepath.Join(repoDir, "folders to be copied to .config")
		}

		if _, err := os.Stat(configSource); os.IsNotExist(err) {
			fmt.Println(ui.Error("Carpeta de configuraciones no encontrada"))
			return
		}

		homeDir, _ := os.UserHomeDir()
		configDest := filepath.Join(homeDir, ".config")

		// Contar archivos
		var fileCount int
		filepath.WalkDir(configSource, func(path string, d fs.DirEntry, err error) error {
			if err == nil && !d.IsDir() {
				fileCount++
			}
			return nil
		})

		// Confirmación
		confirm := noConfirm
		if !noConfirm {
			form := ui.NewForm(
				huh.NewGroup(
					huh.NewConfirm().
						Title(fmt.Sprintf("Se copiarán %d archivos a ~/.config", fileCount)).
						Description("Los archivos existentes serán sobrescritos").
						Affirmative("Copiar").
						Negative("Cancelar").
						Value(&confirm),
				),
			)

			if err := form.Run(); err != nil || !confirm {
				fmt.Println(ui.Warning("Copia cancelada"))
				return
			}
		}

		fmt.Println(ui.Info("Copiando configuraciones..."))
		var copied, failed int

		err := filepath.WalkDir(configSource, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return nil
			}

			relPath, _ := filepath.Rel(configSource, path)
			destPath := filepath.Join(configDest, relPath)

			if d.IsDir() {
				os.MkdirAll(destPath, 0755)
				return nil
			}

			// Copiar archivo
			data, err := os.ReadFile(path)
			if err != nil {
				logger.Error("Error leyendo %s: %v", path, err)
				failed++
				return nil
			}

			os.MkdirAll(filepath.Dir(destPath), 0755)

			if err := os.WriteFile(destPath, data, 0644); err != nil {
				logger.Error("Error escribiendo %s: %v", destPath, err)
				failed++
				return nil
			}

			copied++
			logger.Info("Copiado: %s", relPath)
			return nil
		})

		if err != nil {
			fmt.Println(ui.Error(fmt.Sprintf("Error: %v", err)))
			return
		}

		fmt.Println(ui.Success(fmt.Sprintf("Copiados: %d archivos", copied)))
		if failed > 0 {
			fmt.Println(ui.Warning(fmt.Sprintf("Fallidos: %d archivos", failed)))
		}
		logger.Info("Copia completada: %d copiados, %d fallidos", copied, failed)
	}

	if watch {
		// Verificar si ya estamos dentro de tmux (para evitar bucle infinito)
		insideTmux := os.Getenv("TMUX") != ""

		if !insideTmux {
			// ------------ WATCH MODE WITH TMUX ------------
			// Verificar que tmux esté disponible
			if !utils.CommandExists("tmux") {
				fmt.Println(ui.Error("tmux no está instalado. Instálalo para usar el modo watch con paneles."))
				fmt.Println(ui.Info("Instala con: sudo pacman -S tmux"))
				os.Exit(1)
			}

			// Obtener la ruta del ejecutable orgmos
			orgmosPath, err := os.Executable()
			if err != nil {
				fmt.Println(ui.Error(fmt.Sprintf("Error obteniendo ruta del ejecutable: %v", err)))
				os.Exit(1)
			}

			// Construir el comando orgmos con los flags correctos
			orgmosCmd := []string{orgmosPath, "config", "--watch"}
			if noConfirm {
				orgmosCmd = append(orgmosCmd, "--no-confirm")
			}
			if delayRun > 0 {
				orgmosCmd = append(orgmosCmd, fmt.Sprintf("--delay-run=%d", delayRun))
			}
			orgmosCmdStr := strings.Join(orgmosCmd, " ")

			logger.Info("Lanzando tmux con comando orgmos: %s", orgmosCmdStr)

			// Construir el script de tmux
			// Primero, eliminar sesión existente si existe
			exec.Command("tmux", "kill-session", "-t", "orgmos-watch").Run()

			// Crear nueva sesión en background
			createSession := exec.Command("tmux", "new-session", "-d", "-s", "orgmos-watch")
			if err := createSession.Run(); err != nil {
				fmt.Println(ui.Error(fmt.Sprintf("Error creando sesión tmux: %v", err)))
				os.Exit(1)
			}

			// Dividir ventana verticalmente y ejecutar watch en el panel inferior
			// El panel inferior monitoreará el panel superior y se cerrará cuando termine
			// Usamos un script que ejecuta watch en background y monitorea el panel superior
			watchScript := `watch -n 1 niri validate & WATCH_PID=$!; while tmux list-panes -t orgmos-watch:0.0 >/dev/null 2>&1; do sleep 1; done; kill $WATCH_PID 2>/dev/null; tmux kill-session -t orgmos-watch 2>/dev/null`
			splitWindow := exec.Command("tmux", "split-window", "-v", "-t", "orgmos-watch", "sh", "-c", watchScript)
			if err := splitWindow.Run(); err != nil {
				fmt.Println(ui.Error(fmt.Sprintf("Error dividiendo ventana: %v", err)))
				os.Exit(1)
			}

			// Seleccionar panel superior
			selectPane := exec.Command("tmux", "select-pane", "-t", "orgmos-watch:0.0")
			if err := selectPane.Run(); err != nil {
				fmt.Println(ui.Error(fmt.Sprintf("Error seleccionando panel: %v", err)))
				os.Exit(1)
			}

			// Enviar comando orgmos al panel superior
			sendKeys := exec.Command("tmux", "send-keys", "-t", "orgmos-watch:0.0", orgmosCmdStr, "C-m")
			if err := sendKeys.Run(); err != nil {
				fmt.Println(ui.Error(fmt.Sprintf("Error enviando comando: %v", err)))
				os.Exit(1)
			}

			logger.Info("Sesión tmux creada. Adjuntando...")
			
			// Configurar limpieza cuando se salga de tmux
			defer func() {
				logger.Info("Limpiando sesión tmux...")
				exec.Command("tmux", "kill-session", "-t", "orgmos-watch").Run()
			}()

			// Adjuntar a la sesión (esto bloqueará hasta que se salga de tmux)
			attachSession := exec.Command("tmux", "attach-session", "-t", "orgmos-watch")
			attachSession.Stdout = os.Stdout
			attachSession.Stderr = os.Stderr
			attachSession.Stdin = os.Stdin

			// Cuando attach termine (usuario salió de tmux), el defer limpiará la sesión
			if err := attachSession.Run(); err != nil {
				// Si hay error, puede ser que el usuario salió con Ctrl+C o similar
				logger.Info("Sesión tmux terminada")
			}
			return
		}

		// Si ya estamos dentro de tmux, ejecutar el loop de watch normalmente
		// ------------ WATCH MODE (INSIDE TMUX) ------------
		
		// Configurar handler para limpiar la sesión de tmux cuando se reciba Ctrl+C
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
		
		// Función para limpiar la sesión de tmux
		cleanupTmux := func() {
			logger.Info("Limpiando sesión tmux...")
			// El panel inferior ya debería cerrar la sesión automáticamente,
			// pero por si acaso, lo intentamos también
			exec.Command("tmux", "kill-session", "-t", "orgmos-watch").Run()
		}
		
		// Asegurar limpieza al salir
		defer cleanupTmux()
		
		// Goroutine para manejar señales
		go func() {
			<-sigChan
			fmt.Println(ui.Info("\nDeteniendo watch..."))
			// Cuando este proceso termine, el panel inferior detectará que el panel superior
			// ya no existe y cerrará automáticamente la sesión
			os.Exit(0)
		}()

		prevHash := ""
		delay := time.Duration(delayRun) * time.Second

		printColorGum(ui.Info("Modo watch: esperando cambios en configuraciones..."))
		printColorGum(ui.Dim("Presiona Ctrl+C para detener y cerrar la sesión"))
		
		for {
			repoDir := utils.GetConfigRepoDir()
			if repoDir == "" {
				repoDir = utils.GetRepoDir()
			}
			configSource := filepath.Join(repoDir, "configs_to_copy")
			if _, err := os.Stat(configSource); os.IsNotExist(err) {
				configSource = filepath.Join(repoDir, "folders to be copied to .config")
			}

			// Simple hash con mtime + tamaño total
			hash := ""
			fileCount := 0
			filepath.WalkDir(configSource, func(path string, d fs.DirEntry, err error) error {
				if err == nil && !d.IsDir() {
					info, err := d.Info()
					if err == nil {
						hash += fmt.Sprintf("%s-%d|", info.ModTime(), info.Size())
						fileCount++
					}
				}
				return nil
			})

			// Si cambia hash, se copia (con delay opcional)
			if hash != prevHash {
				fmt.Print(ui.Info(fmt.Sprintf("Detectado cambio en configuraciones (%d archivos)!", fileCount)))
				if delay > 0 {
					fmt.Println(ui.Dim(fmt.Sprintf(" Esperando %ds antes de copiar...", delayRun)))
					time.Sleep(delay)
				} else {
					fmt.Println()
				}
				copyFunc()
				prevHash = hash
				fmt.Println(ui.Dim("Vigilando nuevos cambios..."))
			}
			time.Sleep(2 * time.Second)
		}
	} else {
		// ------------ NORMAL MODE ------------
		copyFunc()
	}
}

