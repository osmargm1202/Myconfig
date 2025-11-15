package models

import (
	"orgmos-pacman/ui"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/list"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type appKeyMap struct {
	Installed key.Binding
	Search    key.Binding
	Quit      key.Binding
}

func (k appKeyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Installed, k.Search, k.Quit}
}

func (k appKeyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.Installed, k.Search, k.Quit},
	}
}

var appKeys = appKeyMap{
	Installed: key.NewBinding(
		key.WithKeys("1", "i"),
		key.WithHelp("1/i", "paquetes instalados"),
	),
	Search: key.NewBinding(
		key.WithKeys("2", "s"),
		key.WithHelp("2/s", "buscar paquetes"),
	),
	Quit: key.NewBinding(
		key.WithKeys("ctrl+c", "q"),
		key.WithHelp("ctrl+c/q", "salir"),
	),
}

type ViewType int

const (
	MenuView ViewType = iota
	InstalledView
	SearchView
)

type menuItem struct {
	title       string
	description string
	view        ViewType
}

func (i menuItem) FilterValue() string { return "" }
func (i menuItem) Title() string       { return i.title }
func (i menuItem) Description() string { return i.description }

type AppModel struct {
	currentView ViewType
	menu        list.Model
	installed   InstalledModel
	search      SearchModel
	keys        appKeyMap
}

func NewAppModel() AppModel {
	items := []list.Item{
		menuItem{
			title:       "Paquetes Instalados",
			description: "Ver y desinstalar paquetes instalados",
			view:        InstalledView,
		},
		menuItem{
			title:       "Buscar Paquetes",
			description: "Buscar e instalar paquetes desde AUR y repositorios",
			view:        SearchView,
		},
	}

	// Crear delegate compacto para el menú
	delegate := list.NewDefaultDelegate()
	delegate.Styles.SelectedTitle = lipgloss.NewStyle().
		Foreground(ui.SelectedColor).
		Bold(true).
		Border(lipgloss.NormalBorder(), false, false, false, true).
		BorderForeground(ui.SelectedColor).
		Padding(0, 0, 0, 1)
	delegate.Styles.SelectedDesc = delegate.Styles.SelectedTitle.Copy().
		Foreground(ui.SelectedColor).
		Bold(false)
	delegate.Styles.NormalTitle = lipgloss.NewStyle().
		Foreground(ui.ForegroundColor).
		Padding(0, 0, 0, 1)
	delegate.Styles.NormalDesc = delegate.Styles.NormalTitle.Copy().
		Foreground(lipgloss.Color("#565f89"))

	menuList := list.New(items, delegate, 0, 0)
	menuList.Title = "ORGMOS Gestor de Paquetes"
	menuList.SetShowStatusBar(false)
	menuList.SetFilteringEnabled(false)
	menuList.Styles.Title = lipgloss.NewStyle().Foreground(ui.TitleColor).Bold(true)
	menuList.Styles.PaginationStyle = ui.HelpStyle
	menuList.Styles.HelpStyle = ui.HelpStyle
	menuList.SetShowHelp(true)

	return AppModel{
		currentView: MenuView,
		menu:        menuList,
		installed:   NewInstalledModel(),
		search:      NewSearchModel(),
		keys:        appKeys,
	}
}

func (m AppModel) Init() tea.Cmd {
	return tea.Batch(
		m.installed.Init(),
		m.search.Init(),
	)
}

func (m AppModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	// Manejar BackMsg primero
	if _, ok := msg.(BackMsg); ok {
		m.currentView = MenuView
		return m, nil
	}

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.menu.SetWidth(msg.Width - 4)
		m.menu.SetHeight(msg.Height - 4)
		var cmd tea.Cmd
		var model tea.Model
		model, cmd = m.installed.Update(msg)
		m.installed = model.(InstalledModel)
		cmds = append(cmds, cmd)
		model, cmd = m.search.Update(msg)
		m.search = model.(SearchModel)
		cmds = append(cmds, cmd)

	case tea.KeyMsg:
		// Verificar si estamos en modo input o terminal de instalación antes de procesar teclas del menú
		isInInputMode := false
		if m.currentView == InstalledView && m.installed.state == InstalledInput {
			isInInputMode = true
		}
		if m.currentView == SearchView {
			if m.search.state == SearchInput || m.search.state == SearchInstallTerminal {
				isInInputMode = true
			}
		}

		// Solo procesar teclas del menú si NO estamos en modo input o terminal
		if !isInInputMode {
			switch {
			case key.Matches(msg, m.keys.Quit):
				return m, tea.Quit

			case key.Matches(msg, m.keys.Installed):
				if m.currentView != InstalledView {
					m.currentView = InstalledView
					// Reinicializar el modelo de instalados si es necesario
					m.installed = NewInstalledModel()
					cmds = append(cmds, m.installed.Init())
				}

			case key.Matches(msg, m.keys.Search):
				if m.currentView != SearchView {
					m.currentView = SearchView
					// Reinicializar el modelo de búsqueda si es necesario
					m.search = NewSearchModel()
					cmds = append(cmds, m.search.Init())
				}
			}
		}
	}

	// Actualizar la vista actual
	switch m.currentView {
	case InstalledView:
		var cmd tea.Cmd
		var model tea.Model
		model, cmd = m.installed.Update(msg)
		m.installed = model.(InstalledModel)
		cmds = append(cmds, cmd)

	case SearchView:
		var cmd tea.Cmd
		var model tea.Model
		model, cmd = m.search.Update(msg)
		m.search = model.(SearchModel)
		cmds = append(cmds, cmd)

	case MenuView:
		// Actualizar el menú
		var cmd tea.Cmd
		m.menu, cmd = m.menu.Update(msg)
		cmds = append(cmds, cmd)

		// Manejar selección en el menú
		if msg, ok := msg.(tea.KeyMsg); ok {
			if msg.Type == tea.KeyEnter {
				if selectedItem := m.menu.SelectedItem(); selectedItem != nil {
					item := selectedItem.(menuItem)
					m.currentView = item.view
					if item.view == InstalledView {
						m.installed = NewInstalledModel()
						cmds = append(cmds, m.installed.Init())
					} else if item.view == SearchView {
						m.search = NewSearchModel()
						cmds = append(cmds, m.search.Init())
					}
				}
			}
		}
	}

	return m, tea.Batch(cmds...)
}

func (m AppModel) View() string {
	switch m.currentView {
	case InstalledView:
		return m.installed.View()
	case SearchView:
		return m.search.View()
	case MenuView:
		return m.menuView()
	default:
		return m.menuView()
	}
}

func (m AppModel) menuView() string {
	return m.menu.View()
}

// BackMsg es un mensaje para volver al menú principal
type BackMsg struct{}

