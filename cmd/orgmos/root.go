package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"

	"orgmos/internal/logger"
	"orgmos/internal/ui"
	"orgmos/internal/utils"
)

var (
	cfgFile string
	rootCmd = &cobra.Command{
		Use:   "orgmos",
		Short: "ORGMOS - Sistema de configuración para Arch Linux",
		Long: `ORGMOS es una herramienta de configuración y automatización
para sistemas Arch Linux con i3, Hyprland, Niri o Sway.

Usa 'orgmos menu' para acceder al menú interactivo o ejecuta
'orgmos [comando] --help' para ver la ayuda de un comando específico.`,
		PersistentPreRun: func(cmd *cobra.Command, args []string) {
			// Actualizar repo al iniciar
			utils.UpdateRepo()
			// Crear desktop file
			utils.CreateDesktopFile()
		},
		Run: func(cmd *cobra.Command, args []string) {
			cmd.Help()
		},
	}
)

// Execute ejecuta el comando raíz
func Execute() error {
	return rootCmd.Execute()
}

func init() {
	cobra.OnInitialize(initConfig)

	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "archivo de configuración")
	rootCmd.PersistentFlags().BoolP("verbose", "v", false, "salida detallada")

	viper.BindPFlag("verbose", rootCmd.PersistentFlags().Lookup("verbose"))
}

func initConfig() {
	if cfgFile != "" {
		viper.SetConfigFile(cfgFile)
	} else {
		home, err := os.UserHomeDir()
		if err != nil {
			fmt.Println(ui.Error(err.Error()))
			os.Exit(1)
		}

		viper.AddConfigPath(home)
		viper.SetConfigType("yaml")
		viper.SetConfigName(".orgmos")
	}

	viper.AutomaticEnv()

	if err := viper.ReadInConfig(); err == nil {
		logger.Info("Usando config: %s", viper.ConfigFileUsed())
	}
}

