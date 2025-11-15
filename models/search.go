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

type searchKeyMap struct {
	Install key.Binding
	Back    key.Binding
	Search  key.Binding
}

func (k searchKeyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Install, k.Search, k.Back}
}

func (k searchKeyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.Install, k.Search, k.Back},
	}
}

var searchKeys = searchKeyMap{
	Install: key.NewBinding(
		key.WithKeys("ctrl+i", "enter"),
		key.WithHelp("ctrl+i/enter", "instalar"),
	),
	Search: key.NewBinding(
		key.WithKeys("ctrl+f"),
		key.WithHelp("ctrl+f", "buscar"),
	),
	Back: key.NewBinding(
		key.WithKeys("esc", "q"),
		key.WithHelp("esc/q", "volver"),
	),
}

type SearchState int

const (
	SearchInput SearchState = iota
	SearchResults
	SearchInstalling
	SearchInstallTerminal
)

type SearchModel struct {
	table          table.Model
	search         textinput.Model
	filter         textinput.Model
	packages       []pkg.Package
	filtered       []pkg.Package
	keys           searchKeyMap
	loading        bool
	state          SearchState
	filtering      bool
	error          string
	success        string
	lastQuery      string
	installOutput  []string
	installingPkg  string
	progressChan   <-chan pkg.InstallProgress
	installTerminal InstallTerminalModel
}

func NewSearchModel() SearchModel {
	search := textinput.New()
	search.Placeholder = "Buscar paquetes (ej: epson 3251)..."
	search.Focus() // Enfocar por defecto en modo input
	search.CharLimit = 100
	search.Width = 90

	// Crear tabla con columnas más anchas para que todo se vea en una línea
	columns := []table.Column{
		{Title: "Nombre", Width: 50},
		{Title: "Versión", Width: 20},
		{Title: "Repositorio", Width: 18},
		{Title: "Estado", Width: 12},
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

	filter := textinput.New()
	filter.Placeholder = "Filtrar en tabla..."
	filter.CharLimit = 100
	filter.Width = 50

	return SearchModel{
		table:     t,
		search:    search,
		filter:    filter,
		packages:  []pkg.Package{},
		filtered:  []pkg.Package{},
		keys:      searchKeys,
		loading:   false,
		state:     SearchInput,
		filtering: false,
	}
}

func (m SearchModel) Init() tea.Cmd {
	m.search.Focus()
	return textinput.Blink
}

func (m SearchModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		// Hacer que input y tabla tengan el mismo ancho (un poco más pequeño)
		tableWidth := msg.Width - 8
		m.search.Width = tableWidth - 2
		m.filter.Width = tableWidth - 2
		if m.state == SearchResults {
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
		
		// Si estamos en modo input, enfocar el search
		if m.state == SearchInput {
			m.search.Focus()
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
		if m.state == SearchInput {
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
				// Buscar cuando se presiona Enter
				query := strings.TrimSpace(m.search.Value())
				if query != "" {
					m.lastQuery = query
					m.loading = true
					m.state = SearchResults
					m.search.Blur()
					return m, searchPackages(query)
				}

			default:
				// Manejar entrada de texto normal - SIEMPRE actualizar el search
				var cmd tea.Cmd
				m.search, cmd = m.search.Update(msg)
				cmds = append(cmds, cmd)
			}
		} else {
			// Modo resultados: tabla de resultados
			if m.filtering {
				// Modo filtrado activo
				switch {
				case msg.Type == tea.KeyEsc:
					// Salir del modo filtrado
					m.filtering = false
					m.filter.Blur()
					m.filter.SetValue("")
					m.updateTable(m.packages)
					return m, nil

				case msg.Type == tea.KeyEnter:
					// Aplicar filtro
					m.filtering = false
					m.filter.Blur()
					query := strings.TrimSpace(m.filter.Value())
					if query != "" {
						m.filtered = pkg.FilterPackages(m.packages, query)
					} else {
						m.filtered = m.packages
					}
					m.updateTable(m.filtered)
					return m, nil

				default:
					// Manejar entrada de texto
					var cmd tea.Cmd
					m.filter, cmd = m.filter.Update(msg)
					cmds = append(cmds, cmd)
					
					// Filtrar en tiempo real
					query := strings.TrimSpace(m.filter.Value())
					if query != "" {
						m.filtered = pkg.FilterPackages(m.packages, query)
					} else {
						m.filtered = m.packages
					}
					m.updateTable(m.filtered)
				}
			} else {
				// Modo normal de tabla
				switch {
				case msg.Type == tea.KeyEsc:
					// Volver a la búsqueda
					m.state = SearchInput
					m.search.Focus()
					return m, textinput.Blink

				case msg.String() == "f":
					// Activar modo filtrado
					m.filtering = true
					m.filter.Focus()
					m.filter.SetValue("")
					return m, textinput.Blink

				case key.Matches(msg, m.keys.Install) || msg.Type == tea.KeyEnter:
					// Instalar paquete seleccionado - abrir terminal de instalación
					if m.table.SelectedRow() != nil && len(m.table.SelectedRow()) > 0 {
						pkgName := m.table.SelectedRow()[0]
						m.state = SearchInstallTerminal
						m.installTerminal = NewInstallTerminalModel(pkgName)
						return m, m.installTerminal.Init()
					}

				default:
					// Actualizar la tabla
					var cmd tea.Cmd
					m.table, cmd = m.table.Update(msg)
					cmds = append(cmds, cmd)
				}
			}
		}

	case searchResultMsg:
		m.packages = msg.packages
		m.loading = false
		m.state = SearchResults
		// NO aplicar filtrado flexible aquí - yay -Ss ya hace la búsqueda
		// Solo aplicar el filtro de tabla si existe
		filterQuery := strings.TrimSpace(m.filter.Value())
		if filterQuery != "" {
			m.filtered = pkg.FilterPackages(m.packages, filterQuery)
		} else {
			m.filtered = m.packages
		}
		
		m.updateTable(m.filtered)
		m.search.Blur()

	case installStartMsg:
		// Iniciar instalación
		m.state = SearchInstalling
		m.installingPkg = msg.pkgName
		m.installOutput = []string{}
		m.progressChan = msg.progressChan
		// Iniciar ticker para leer progreso
		return m, tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg {
			return readInstallProgress(m.progressChan)()
		})

	case installProgressMsg:
		// Actualizar progreso
		if m.state == SearchInstalling {
			m.installOutput = msg.progress.Output
			
			if msg.progress.Done {
				// Instalación terminada
				if msg.progress.Error != nil {
					m.error = fmt.Sprintf("Error: %v", msg.progress.Error)
					m.state = SearchResults
				} else {
					m.success = fmt.Sprintf("Paquete %s instalado exitosamente", msg.progress.PackageName)
					m.state = SearchResults
					// Recargar búsqueda para actualizar estado de instalación
					if m.lastQuery != "" {
						m.loading = true
						cmds = append(cmds, searchPackages(m.lastQuery))
					}
				}
				m.progressChan = nil
			} else {
				// Continuar leyendo progreso
				cmds = append(cmds, tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg {
					return readInstallProgress(m.progressChan)()
				}))
			}
		}

	case installResultMsg:
		if msg.err != nil {
			m.error = fmt.Sprintf("Error: %v", msg.err)
		} else {
			m.success = fmt.Sprintf("Paquete %s instalado exitosamente", msg.pkgName)
			// Recargar búsqueda para actualizar estado de instalación
			if m.lastQuery != "" {
				m.loading = true
				return m, searchPackages(m.lastQuery)
			}
		}
	}

	// Si estamos en modo terminal de instalación, actualizar ese modelo
	if m.state == SearchInstallTerminal {
		var cmd tea.Cmd
		var model tea.Model
		model, cmd = m.installTerminal.Update(msg)
		m.installTerminal = model.(InstallTerminalModel)
		
		// Si la instalación terminó, volver a resultados
		if m.installTerminal.done {
			m.state = SearchResults
			if m.installTerminal.err != nil {
				m.error = fmt.Sprintf("Error: %v", m.installTerminal.err)
			} else {
				m.success = fmt.Sprintf("Paquete %s instalado exitosamente", m.installTerminal.pkgName)
				// Recargar búsqueda para actualizar estado de instalación
				if m.lastQuery != "" {
					m.loading = true
					cmds = append(cmds, searchPackages(m.lastQuery))
				}
			}
		} else {
			cmds = append(cmds, cmd)
		}
	}

	return m, tea.Batch(cmds...)
}

func (m SearchModel) View() string {
	var s strings.Builder
	s.WriteString(ui.RenderTitle())
	s.WriteString("\n\n")

	// Obtener ancho de la tabla para usar en el renderizado
	tableWidth := m.table.Width()
	if tableWidth == 0 {
		tableWidth = 100
	}

	if m.state == SearchInput {
		// Modo input: solo barra de búsqueda
		searchBox := ui.RenderSearchBox(m.search.View(), tableWidth)
		s.WriteString(searchBox)
		s.WriteString("\n\n")

		if m.loading {
			s.WriteString("Buscando paquetes...\n\n")
		} else {
			s.WriteString(ui.RenderHelp("Presiona Enter para buscar, Esc para volver al menú"))
		}
	} else if m.state == SearchInstalling {
		// Modo instalación: mostrar progreso
		s.WriteString(fmt.Sprintf("Instalando paquete: %s\n\n", m.installingPkg))
		
		// Mostrar salida (últimas 20 líneas para no saturar)
		outputLines := m.installOutput
		start := 0
		if len(outputLines) > 20 {
			start = len(outputLines) - 20
		}
		for i := start; i < len(outputLines); i++ {
			s.WriteString(outputLines[i])
			s.WriteString("\n")
		}
		
		s.WriteString("\n")
		s.WriteString(ui.RenderHelp("Instalando... Por favor espera"))
	} else if m.state == SearchInstallTerminal {
		// Modo terminal de instalación interactiva
		return m.installTerminal.View()
	} else {
		// Modo resultados: tabla de resultados
		if m.filtering {
			// Mostrar campo de filtrado
			filterBox := ui.RenderSearchBox(m.filter.View(), tableWidth)
			s.WriteString(filterBox)
			s.WriteString("\n\n")
			s.WriteString(ui.RenderHelp("Presiona Enter para aplicar filtro, Esc para cancelar"))
		} else {
			searchBox := ui.RenderSearchBox(m.search.View(), tableWidth)
			s.WriteString(searchBox)
			s.WriteString("\n\n")

			if m.loading {
				s.WriteString("Buscando paquetes...\n\n")
			} else {
				// Tabla de resultados - renderizar directamente sin bordes adicionales
				tableView := m.table.View()
				s.WriteString(tableView)
				s.WriteString("\n\n")
			}
		}

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
		if !m.filtering {
			help := m.keys.FullHelp()[0]
			helpText := ""
			for _, k := range help {
				helpText += fmt.Sprintf("%s %s  ", k.Help().Key, k.Help().Desc)
			}
			helpText += "f filtrar  esc volver a búsqueda"
			s.WriteString(ui.RenderHelp(helpText))
		}
	}

	return s.String()
}

func (m *SearchModel) updateTable(packages []pkg.Package) {
	rows := make([]table.Row, len(packages))
	for i, p := range packages {
		repo := p.Repository
		if repo == "" {
			repo = "unknown"
		}
		
		// Verificar que la versión no esté vacía
		version := p.Version
		if version == "" {
			version = "N/A"
		}
		
		estado := ""
		if p.Installed {
			estado = "instalado"
		} else {
			estado = "-"
		}
		rows[i] = table.Row{p.Name, version, repo, estado}
	}
	m.table.SetRows(rows)
}

// Mensajes
type searchResultMsg struct {
	packages []pkg.Package
}

type installResultMsg struct {
	pkgName string
	err     error
}

type installProgressMsg struct {
	progress pkg.InstallProgress
}

func searchPackages(query string) tea.Cmd {
	return func() tea.Msg {
		packages, err := pkg.SearchPackages(query)
		if err != nil {
			return searchResultMsg{packages: []pkg.Package{}}
		}
		// Retornar todos los paquetes, el filtrado se hace en el modelo
		return searchResultMsg{packages: packages}
	}
}

// openInstallTerminal ya no se usa, se maneja directamente en el modelo

// Mantener installPackage por compatibilidad, pero ya no se usa
func installPackage(pkgName string) tea.Cmd {
	return func() tea.Msg {
		progressChan := make(chan pkg.InstallProgress, 100)
		go pkg.InstallPackage(pkgName, progressChan)
		
		// Retornar un mensaje especial que indique que se inició la instalación
		// El canal se pasará a través de un mensaje especial
		return installStartMsg{
			pkgName:     pkgName,
			progressChan: progressChan,
		}
	}
}

type installStartMsg struct {
	pkgName      string
	progressChan <-chan pkg.InstallProgress
}

func readInstallProgress(progressChan <-chan pkg.InstallProgress) tea.Cmd {
	return func() tea.Msg {
		select {
		case progress, ok := <-progressChan:
			if !ok {
				return installProgressMsg{
					progress: pkg.InstallProgress{Done: true},
				}
			}
			return installProgressMsg{progress: progress}
		default:
			// No hay mensaje disponible todavía, retornar nil para no bloquear
			return nil
		}
	}
}

