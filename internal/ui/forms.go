package ui

import (
	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/huh"
)

// NewForm crea un formulario con soporte para salir usando Esc.
func NewForm(groups ...*huh.Group) *huh.Form {
	form := huh.NewForm(groups...)

	keyMap := huh.NewDefaultKeyMap()
	keyMap.Quit = key.NewBinding(
		key.WithKeys("esc", "ctrl+c"),
		key.WithHelp("esc", "salir"),
	)

	form.WithKeyMap(keyMap)
	return form
}

