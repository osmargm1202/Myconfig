package models

import (
	"fmt"
	"os/exec"
	"strings"
	"syscall"
	"time"

	"orgmos-pacman/ui"

	"github.com/charmbracelet/bubbles/key"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

type installTerminalKeyMap struct {
	Quit key.Binding
}

func (k installTerminalKeyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Quit}
}

func (k installTerminalKeyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.Quit},
	}
}

var installTerminalKeys = installTerminalKeyMap{
	Quit: key.NewBinding(
		key.WithKeys("ctrl+c", "q"),
		key.WithHelp("ctrl+c/q", "cerrar (solo cuando termine)"),
	),
}

type InstallTerminalModel struct {
	pkgName    string
	done       bool
	err        error
	keys       installTerminalKeyMap
	width      int
	height     int
	waiting    bool
	cmd        *exec.Cmd
}

func NewInstallTerminalModel(pkgName string) InstallTerminalModel {
	return InstallTerminalModel{
		pkgName: pkgName,
		keys:    installTerminalKeys,
		width:   80,
		height:  24,
		waiting: false,
	}
}

// findTerminal busca qué terminal está disponible en el sistema
func findTerminal() string {
	terminals := []string{"kitty", "alacritty", "gnome-terminal", "xterm", "x-terminal-emulator"}
	for _, term := range terminals {
		if _, err := exec.LookPath(term); err == nil {
			return term
		}
	}
	return ""
}

func (m InstallTerminalModel) Init() tea.Cmd {
	return func() tea.Msg {
		// Buscar terminal disponible
		term := findTerminal()
		if term == "" {
			return installTerminalDoneMsg{
				err: fmt.Errorf("no se encontró ningún terminal disponible (kitty, alacritty, gnome-terminal, xterm)"),
			}
		}

		// Construir comando según el terminal
		var cmd *exec.Cmd
		installCmd := fmt.Sprintf("yay -S %s; echo ''; echo 'Instalación completada. Presiona Enter para cerrar.'; read", m.pkgName)
		
		switch term {
		case "kitty":
			cmd = exec.Command("kitty", "--hold", "-e", "bash", "-c", installCmd)
		case "alacritty":
			cmd = exec.Command("alacritty", "--hold", "-e", "bash", "-c", installCmd)
		case "gnome-terminal":
			cmd = exec.Command("gnome-terminal", "--", "bash", "-c", installCmd+"; exec bash")
		case "xterm":
			cmd = exec.Command("xterm", "-hold", "-e", "bash", "-c", installCmd)
		default:
			cmd = exec.Command(term, "-e", "bash", "-c", installCmd)
		}

		// Ejecutar el comando en una nueva terminal
		err := cmd.Start()
		if err != nil {
			return installTerminalDoneMsg{
				err: fmt.Errorf("error iniciando terminal: %w", err),
			}
		}

		// Proceso iniciado, esperar a que termine
		return installTerminalStartedMsg{
			cmd: cmd,
		}
	}
}

func (m InstallTerminalModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case tea.KeyMsg:
		// Si el comando terminó, permitir salir
		if m.done {
			if key.Matches(msg, m.keys.Quit) {
				return m, tea.Quit
			}
			return m, nil
		}
		// Mientras espera, solo permitir salir con Ctrl+C
		if key.Matches(msg, m.keys.Quit) {
			return m, tea.Quit
		}

	case installTerminalStartedMsg:
		m.waiting = true
		m.cmd = msg.cmd
		// Verificar periódicamente si el proceso terminó
		cmds = append(cmds, tea.Tick(1*time.Second, func(t time.Time) tea.Msg {
			return installTerminalCheckMsg{}
		}))

	case installTerminalCheckMsg:
		if m.waiting && !m.done && m.cmd != nil {
			// Verificar si el proceso terminó
			if m.cmd.Process != nil {
				// Usar syscall.Kill con señal 0 para verificar si el proceso existe
				// (no envía señal real, solo verifica)
				err := syscall.Kill(m.cmd.Process.Pid, 0)
				if err != nil {
					// El proceso terminó (err != nil significa que no existe)
					m.cmd.Wait()
					m.done = true
					m.waiting = false
					if m.cmd.ProcessState != nil && !m.cmd.ProcessState.Success() {
						m.err = fmt.Errorf("instalación falló con código de salida %d", m.cmd.ProcessState.ExitCode())
					}
					return m, nil
				}
			}
			// Continuar verificando
			cmds = append(cmds, tea.Tick(1*time.Second, func(t time.Time) tea.Msg {
				return installTerminalCheckMsg{}
			}))
		}

	case installTerminalDoneMsg:
		m.done = true
		m.waiting = false
		m.err = msg.err
		return m, nil
	}

	return m, tea.Batch(cmds...)
}

func (m InstallTerminalModel) View() string {
	var s strings.Builder
	
	// Título
	title := fmt.Sprintf("Instalando: %s", m.pkgName)
	s.WriteString(ui.RenderTitle())
	s.WriteString("\n\n")
	s.WriteString(lipgloss.NewStyle().
		Foreground(ui.TitleColor).
		Bold(true).
		Width(m.width - 4).
		Render(title))
	s.WriteString("\n\n")
	
	// Mensaje informativo
	if m.done {
		if m.err != nil {
			s.WriteString(ui.ErrorTextStyle.Render(fmt.Sprintf("Error: %v", m.err)))
			s.WriteString("\n\n")
			s.WriteString(ui.RenderHelp("Presiona Ctrl+C o Q para volver"))
		} else {
			s.WriteString(ui.SuccessTextStyle.Render("Instalación completada exitosamente"))
			s.WriteString("\n\n")
			s.WriteString(ui.RenderHelp("Presiona Ctrl+C o Q para volver"))
		}
	} else {
		info := "Se ha abierto una nueva terminal para la instalación."
		info += "\n\n"
		info += "Puedes introducir opciones y tu clave de sudo en la terminal."
		info += "\n\n"
		info += "Cuando termine la instalación, presiona Enter en la terminal"
		info += "\n"
		info += "y luego vuelve aquí (Ctrl+C o Q)."
		s.WriteString(lipgloss.NewStyle().
			Foreground(lipgloss.Color("#7aa2f7")).
			Width(m.width - 4).
			Render(info))
		s.WriteString("\n\n")
		s.WriteString(ui.RenderHelp("Esperando a que termine la instalación... (Ctrl+C o Q para cancelar)"))
	}
	
	return s.String()
}

type installTerminalStartedMsg struct {
	cmd *exec.Cmd
}

type installTerminalCheckMsg struct{}

type installTerminalDoneMsg struct {
	err error
}

