package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"

	"orgmos/internal/ui"
)

const Version = "1.02"

var (
	cfgFile string
	rootCmd = &cobra.Command{
		Use:     "orgmos",
		Short:   "ORGMOS - Sistema de configuración multi-distro",
		Version: Version,
		Long: `ORGMOS es una herramienta de configuración y automatización
para sistemas Arch Linux, Debian y Ubuntu.

Usa 'orgmos menu' para acceder al menú interactivo o ejecuta
'orgmos [comando] --help' para ver la ayuda de un comando específico.`,
		Run: func(cmd *cobra.Command, args []string) {
			runMenu(cmd, args)
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

	// Cambiar template de versión
	rootCmd.SetVersionTemplate("ORGMOS v{{.Version}}\n")
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
	viper.ReadInConfig()
}
