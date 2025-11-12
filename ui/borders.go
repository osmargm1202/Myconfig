package ui

// RenderBorderedBox renderiza un contenido con bordes redondeados
func RenderBorderedBox(content string, width int) string {
	box := BorderStyle.
		Width(width - 4). // Restar padding y bordes
		Render(content)
	return box
}

// RenderSearchBox renderiza una caja de búsqueda con bordes
func RenderSearchBox(content string, width int) string {
	box := SearchBoxStyle.
		Width(width - 4).
		Render(content)
	return box
}

// RenderListBox renderiza una lista con bordes
func RenderListBox(content string, width int) string {
	box := ListStyle.
		Width(width - 4).
		Render(content)
	return box
}

// RenderTitle renderiza el título de la aplicación
func RenderTitle() string {
	return TitleStyle.Render("ORGMOS Gestor de Paquetes")
}

// RenderHelp renderiza texto de ayuda
func RenderHelp(text string) string {
	return HelpStyle.Render(text)
}

