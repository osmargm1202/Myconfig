package ui

import "github.com/charmbracelet/lipgloss"

// Colores principales del sistema
var (
	Blue    = lipgloss.Color("#0066CC") // Mensajes informativos
	SkyBlue = lipgloss.Color("#87CEEB") // Destacados
	Green   = lipgloss.Color("#00AA00") // Éxito
	Yellow  = lipgloss.Color("#FFCC00") // Advertencias
	Red     = lipgloss.Color("#CC0000") // Errores
	White   = lipgloss.Color("#FFFFFF") // Texto normal
	Gray    = lipgloss.Color("#808080") // Texto secundario
)

// Estilos de texto
var (
	TitleStyle = lipgloss.NewStyle().
			Foreground(SkyBlue).
			Bold(true).
			MarginBottom(1)

	InfoStyle = lipgloss.NewStyle().
			Foreground(Blue)

	SuccessStyle = lipgloss.NewStyle().
			Foreground(Green)

	WarningStyle = lipgloss.NewStyle().
			Foreground(Yellow)

	ErrorStyle = lipgloss.NewStyle().
			Foreground(Red)

	HighlightStyle = lipgloss.NewStyle().
			Foreground(SkyBlue).
			Bold(true)

	DimStyle = lipgloss.NewStyle().
			Foreground(Gray)
)

// Funciones de ayuda para imprimir mensajes
func Title(text string) string {
	return TitleStyle.Render(text)
}

func Info(text string) string {
	return InfoStyle.Render("→ " + text)
}

func Success(text string) string {
	return SuccessStyle.Render("✓ " + text)
}

func Warning(text string) string {
	return WarningStyle.Render("⚠ " + text)
}

func Error(text string) string {
	return ErrorStyle.Render("✗ " + text)
}

func Highlight(text string) string {
	return HighlightStyle.Render(text)
}

func Dim(text string) string {
	return DimStyle.Render(text)
}

