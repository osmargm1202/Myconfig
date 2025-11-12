package models

import (
	"fmt"
	"strings"
	"time"

	"orgmos-pacman/pkg"
	"orgmos-pacman/ui"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/table"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type installedKeyMap struct {
	Delete key.Binding
	Back   key.Binding
}

func (k installedKeyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Delete, k.Back}
}

func (k installedKeyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.Delete, k.Back},
	}
}

var installedKeys = installedKeyMap{
	Delete: key.NewBinding(
		key.WithKeys("d", "delete"),
		key.WithHelp("d", "desinstalar"),
	),
	Back: key.NewBinding(
		key.WithKeys("esc", "q"),
		key.WithHelp("esc/q", "volver"),
	),
}

type InstalledState int

const (
	InstalledInput InstalledState = iota
	InstalledResults
	InstalledUninstalling
)

type InstalledModel struct {
	table          table.Model
	search         textinput.Model
	packages       []pkg.Package
	filtered       []pkg.Package
	keys           installedKeyMap
	loading        bool
	state          InstalledState
	error          string
	success        string
	uninstallOutput []string
	uninstallingPkg string
	progressChan   <-chan pkg.InstallProgress
}

func NewInstalledModel() InstalledModel {
	search := textinput.New()
	search.Placeholder = "Buscar paquetes instalados..."
	search.Focus()
	search.CharLimit = 100
	search.Width = 90

	// Crear tabla con columnas más anchas para que todo se vea en una línea
	columns := []table.Column{
		{Title: "Nombre", Width: 50},
		{Title: "Versión", Width: 20},
		{Title: "Repositorio", Width: 18},
	}

	t := table.New(
		table.WithColumns(columns),
		table.WithRows([]table.Row{}),
		table.WithFocused(true),
		table.WithHeight(30), // Máximo 30 items visibles
	)

	// Estilos de la tabla
	s := table.DefaultStyles()
	s.Header = s.Header.
		BorderStyle(lipgloss.NormalBorder()).
		BorderForeground(ui.BorderColor).
		BorderBottom(true).
		Bold(true).
		Foreground(ui.TitleColor)
	s.Selected = s.Selected.
		Foreground(ui.SelectedColor).
		Bold(true).
		Background(lipgloss.Color("#292e42"))
	t.SetStyles(s)

	return InstalledModel{
		table:    t,
		search:   search,
		packages: []pkg.Package{},
		filtered: []pkg.Package{},
		keys:     installedKeys,
		loading:  true,
		state:    InstalledInput,
	}
}

func (m InstalledModel) Init() tea.Cmd {
	return tea.Batch(
		loadInstalledPackages,
		textinput.Blink,
	)
}

func (m InstalledModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		// Hacer que input y tabla tengan el mismo ancho (un poco más pequeño)
		tableWidth := msg.Width - 8
		m.search.Width = tableWidth - 2
		if m.state == InstalledResults {
			// Ajustar altura de la tabla - máximo 30 items visibles
			height := msg.Height - 10
			if height < 30 {
				height = 30
			}
			if height > 30 {
				height = 30
			}
			m.table.SetWidth(tableWidth)
			m.table.SetHeight(height)
		}

	case tea.KeyMsg:
		// Si hay un error o éxito, cualquier tecla lo limpia
		if m.error != "" || m.success != "" {
			if msg.String() != "" {
				m.error = ""
				m.success = ""
				return m, nil
			}
		}

		// Manejar según el estado actual
		if m.state == InstalledInput {
			// Modo input: solo barra de búsqueda
			// Asegurar que el search esté enfocado
			if !m.search.Focused() {
				m.search.Focus()
				cmds = append(cmds, textinput.Blink)
			}

			switch {
			case msg.Type == tea.KeyEsc:
				// Volver al menú principal
				return m, func() tea.Msg {
					return BackMsg{}
				}

			case msg.Type == tea.KeyEnter:
				// Mostrar resultados cuando se presiona Enter
				query := strings.TrimSpace(m.search.Value())
				m.filtered = pkg.FilterPackages(m.packages, query)
				m.state = InstalledResults
				m.search.Blur()
				m.updateTable()
				return m, nil

			default:
				// Manejar entrada de texto normal
				var cmd tea.Cmd
				m.search, cmd = m.search.Update(msg)
				cmds = append(cmds, cmd)
			}
		} else {
			// Modo resultados: tabla de resultados
			switch {
			case msg.Type == tea.KeyEsc:
				// Volver a la búsqueda
				m.state = InstalledInput
				m.search.Focus()
				return m, textinput.Blink

			case msg.Type == tea.KeyEnter || key.Matches(msg, m.keys.Delete):
				// Desinstalar paquete seleccionado
				if m.table.SelectedRow() != nil && len(m.table.SelectedRow()) > 0 {
					pkgName := m.table.SelectedRow()[0]
					return m, uninstallPackage(pkgName)
				}

			default:
				// Actualizar la tabla
				var cmd tea.Cmd
				m.table, cmd = m.table.Update(msg)
				cmds = append(cmds, cmd)
			}
		}

	case loadedInstalledPackagesMsg:
		m.packages = msg.packages
		m.loading = false
		// Si estamos en modo input, no actualizar la tabla todavía
		if m.state == InstalledResults {
			query := strings.TrimSpace(m.search.Value())
			m.filtered = pkg.FilterPackages(m.packages, query)
			m.updateTable()
		}

	case uninstallStartMsg:
		// Iniciar desinstalación
		m.state = InstalledUninstalling
		m.uninstallingPkg = msg.pkgName
		m.uninstallOutput = []string{}
		m.progressChan = msg.progressChan
		// Iniciar ticker para leer progreso
		return m, tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg {
			return readUninstallProgress(m.progressChan)()
		})

	case uninstallProgressMsg:
		// Actualizar progreso
		if m.state == InstalledUninstalling {
			m.uninstallOutput = msg.progress.Output
			
			if msg.progress.Done {
				// Desinstalación terminada
				if msg.progress.Error != nil {
					m.error = fmt.Sprintf("Error: %v", msg.progress.Error)
					m.state = InstalledResults
				} else {
					m.success = fmt.Sprintf("Paquete %s desinstalado exitosamente", msg.progress.PackageName)
					m.state = InstalledResults
					// Recargar lista de paquetes
					m.loading = true
					cmds = append(cmds, loadInstalledPackages)
				}
				m.progressChan = nil
			} else {
				// Continuar leyendo progreso
				cmds = append(cmds, tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg {
					return readUninstallProgress(m.progressChan)()
				}))
			}
		}

	case uninstallResultMsg:
		if msg.err != nil {
			m.error = fmt.Sprintf("Error: %v", msg.err)
		} else {
			m.success = fmt.Sprintf("Paquete %s desinstalado exitosamente", msg.pkgName)
			// Recargar lista de paquetes
			m.loading = true
			return m, loadInstalledPackages
		}
	}

	return m, tea.Batch(cmds...)
}

func (m InstalledModel) View() string {
	if m.loading && m.state != InstalledUninstalling {
		return ui.RenderTitle() + "\n\nCargando paquetes instalados...\n"
	}

	var s strings.Builder
	s.WriteString(ui.RenderTitle())
	s.WriteString("\n\n")

	// Obtener ancho de la tabla para usar en el renderizado
	tableWidth := m.table.Width()
	if tableWidth == 0 {
		tableWidth = 100
	}

	if m.state == InstalledUninstalling {
		// Modo desinstalación: mostrar progreso
		s.WriteString(fmt.Sprintf("Desinstalando paquete: %s\n\n", m.uninstallingPkg))
		
		// Mostrar salida (últimas 20 líneas para no saturar)
		outputLines := m.uninstallOutput
		start := 0
		if len(outputLines) > 20 {
			start = len(outputLines) - 20
		}
		for i := start; i < len(outputLines); i++ {
			s.WriteString(outputLines[i])
			s.WriteString("\n")
		}
		
		s.WriteString("\n")
		s.WriteString(ui.RenderHelp("Desinstalando... Por favor espera"))
	} else if m.state == InstalledInput {
		// Modo input: solo barra de búsqueda
		searchBox := ui.RenderSearchBox(m.search.View(), tableWidth)
		s.WriteString(searchBox)
		s.WriteString("\n\n")
		s.WriteString(ui.RenderHelp("Presiona Enter para buscar, Esc para volver al menú"))
	} else {
		// Modo resultados: barra de búsqueda + tabla
		searchBox := ui.RenderSearchBox(m.search.View(), tableWidth)
		s.WriteString(searchBox)
		s.WriteString("\n\n")

		// Tabla de resultados - renderizar directamente sin bordes adicionales
		tableView := m.table.View()
		s.WriteString(tableView)
		s.WriteString("\n\n")

		// Mensajes de error o éxito
		if m.error != "" {
			s.WriteString(ui.ErrorTextStyle.Render(m.error))
			s.WriteString("\n")
		}
		if m.success != "" {
			s.WriteString(ui.SuccessTextStyle.Render(m.success))
			s.WriteString("\n")
		}

		// Ayuda
		help := m.keys.FullHelp()[0]
		helpText := ""
		for _, k := range help {
			helpText += fmt.Sprintf("%s %s  ", k.Help().Key, k.Help().Desc)
		}
		helpText += "esc volver a búsqueda"
		s.WriteString(ui.RenderHelp(helpText))
	}

	return s.String()
}

func (m *InstalledModel) updateTable() {
	rows := make([]table.Row, len(m.filtered))
	for i, p := range m.filtered {
		repo := p.Repository
		if repo == "" {
			repo = "local"
		}
		rows[i] = table.Row{p.Name, p.Version, repo}
	}
	m.table.SetRows(rows)
}

// Mensajes
type filterUpdateMsg struct{}

type loadedInstalledPackagesMsg struct {
	packages []pkg.Package
}

type uninstallResultMsg struct {
	pkgName string
	err     error
}

type uninstallStartMsg struct {
	pkgName      string
	progressChan <-chan pkg.InstallProgress
}

type uninstallProgressMsg struct {
	progress pkg.InstallProgress
}

func loadInstalledPackages() tea.Msg {
	packages, err := pkg.GetMainPackages()
	if err != nil {
		return loadedInstalledPackagesMsg{packages: []pkg.Package{}}
	}
	return loadedInstalledPackagesMsg{packages: packages}
}

func uninstallPackage(pkgName string) tea.Cmd {
	return func() tea.Msg {
		progressChan := make(chan pkg.InstallProgress, 100)
		go pkg.UninstallPackage(pkgName, progressChan)
		
		return uninstallStartMsg{
			pkgName:      pkgName,
			progressChan: progressChan,
		}
	}
}

func readUninstallProgress(progressChan <-chan pkg.InstallProgress) tea.Cmd {
	return func() tea.Msg {
		select {
		case progress, ok := <-progressChan:
			if !ok {
				return uninstallProgressMsg{
					progress: pkg.InstallProgress{Done: true},
				}
			}
			return uninstallProgressMsg{progress: progress}
		default:
			return nil
		}
	}
}

