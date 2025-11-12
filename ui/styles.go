package ui

import (
	"github.com/charmbracelet/lipgloss"
)

var (
	// Colores
	BackgroundColor = lipgloss.Color("#1a1b26")
	ForegroundColor = lipgloss.Color("#c0caf5")
	BorderColor     = lipgloss.Color("#7aa2f7")      // Azul para bordes
	TitleColor      = lipgloss.Color("#4A90E2")      // Azul para títulos
	SelectedColor   = lipgloss.Color("#87CEEB")      // Azul cielo para selección
	SuccessColor    = lipgloss.Color("#9ece6a")
	ErrorColor      = lipgloss.Color("#f7768e")
	WarningColor    = lipgloss.Color("#e0af68")

	// Estilos base
	TitleStyle = lipgloss.NewStyle().
			Foreground(TitleColor).
			Bold(true).
			Align(lipgloss.Center).
			Padding(0, 1)

	BorderStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(BorderColor).
			Padding(1, 2)

	SearchBoxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(BorderColor).
			Padding(0, 1)

	ListStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(BorderColor).
			Padding(0, 1)

	SelectedItemStyle = lipgloss.NewStyle().
				Foreground(SelectedColor).
				Bold(true)

	ItemStyle = lipgloss.NewStyle().
			Foreground(ForegroundColor)

	HelpStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#565f89")).
			Italic(true)

	ErrorTextStyle = lipgloss.NewStyle().
			Foreground(ErrorColor)

	SuccessTextStyle = lipgloss.NewStyle().
				Foreground(SuccessColor)
)

