package pkg

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// GetInstalledPackages obtiene la lista de paquetes instalados usando yay -Q o pacman -Q
func GetInstalledPackages() ([]Package, error) {
	// Intentar usar yay primero, luego pacman
	var cmd *exec.Cmd
	if _, err := exec.LookPath("yay"); err == nil {
		cmd = exec.Command("yay", "-Q")
	} else {
		cmd = exec.Command("pacman", "-Q")
	}

	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("error ejecutando comando: %w", err)
	}

	var packages []Package
	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		// Formato: nombre versión
		parts := strings.Fields(line)
		if len(parts) >= 2 {
			pkg := Package{
				Name:      parts[0],
				Version:   parts[1],
				Installed: true,
			}
			packages = append(packages, pkg)
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error leyendo salida: %w", err)
	}

	return packages, nil
}

// GetMainPackages obtiene solo los paquetes principales (no dependencias) usando yay -Qe o pacman -Qe
func GetMainPackages() ([]Package, error) {
	// Intentar usar yay primero, luego pacman
	var cmd *exec.Cmd
	if _, err := exec.LookPath("yay"); err == nil {
		cmd = exec.Command("yay", "-Qe")
	} else {
		cmd = exec.Command("pacman", "-Qe")
	}

	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("error ejecutando comando: %w", err)
	}

	var packages []Package
	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		// Formato: nombre versión
		parts := strings.Fields(line)
		if len(parts) >= 2 {
			pkg := Package{
				Name:      parts[0],
				Version:   parts[1],
				Installed: true,
			}
			packages = append(packages, pkg)
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error leyendo salida: %w", err)
	}

	return packages, nil
}

// removeANSICodes elimina códigos de escape ANSI de una cadena
func removeANSICodes(s string) string {
	// Eliminar códigos de escape ANSI (incluyendo hipervínculos OSC 8)
	// Formato OSC 8: \x1b]8;;URL\x1b\\text\x1b]8;;\x1b\\
	// Eliminar códigos de formato ANSI (CSI)
	ansiRegex1 := regexp.MustCompile(`\x1b\[[0-9;]*[a-zA-Z]`)
	s = ansiRegex1.ReplaceAllString(s, "")
	
	// Eliminar hipervínculos OSC 8: \x1b]8;;URL\x1b\\
	ansiRegex2 := regexp.MustCompile(`\x1b\]8;;[^\x1b]*\x1b\\\\`)
	s = ansiRegex2.ReplaceAllString(s, "")
	
	// Eliminar cierre de hipervínculos: \x1b]8;;\x1b\\
	ansiRegex3 := regexp.MustCompile(`\x1b\]8;;\x1b\\\\`)
	s = ansiRegex3.ReplaceAllString(s, "")
	
	return s
}

// RepoPackageList representa una lista de paquetes de un repositorio con timestamp
type RepoPackageList struct {
	LastUpdated time.Time `json:"lastUpdated"`
	Packages    []Package `json:"packages"`
}

// getConfigDir retorna el directorio de configuración ~/.config/orgm/
func getConfigDir() (string, error) {
	usr, err := user.Current()
	if err != nil {
		return "", fmt.Errorf("error obteniendo usuario actual: %w", err)
	}
	configDir := filepath.Join(usr.HomeDir, ".config", "orgm")
	return configDir, nil
}

// loadRepoListFromFile carga una lista de paquetes desde un archivo JSON
func loadRepoListFromFile(repo string) (RepoPackageList, error) {
	configDir, err := getConfigDir()
	if err != nil {
		return RepoPackageList{}, err
	}

	filePath := filepath.Join(configDir, repo+".json")
	
	data, err := os.ReadFile(filePath)
	if err != nil {
		return RepoPackageList{}, fmt.Errorf("error leyendo archivo: %w", err)
	}

	var list RepoPackageList
	if err := json.Unmarshal(data, &list); err != nil {
		return RepoPackageList{}, fmt.Errorf("error parseando JSON: %w", err)
	}

	return list, nil
}

// saveRepoListToFile guarda una lista de paquetes en un archivo JSON
func saveRepoListToFile(repo string, list RepoPackageList) error {
	configDir, err := getConfigDir()
	if err != nil {
		return err
	}

	// Crear directorio si no existe
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return fmt.Errorf("error creando directorio: %w", err)
	}

	filePath := filepath.Join(configDir, repo+".json")
	
	data, err := json.MarshalIndent(list, "", "  ")
	if err != nil {
		return fmt.Errorf("error serializando JSON: %w", err)
	}

	if err := os.WriteFile(filePath, data, 0644); err != nil {
		return fmt.Errorf("error escribiendo archivo: %w", err)
	}

	return nil
}

// parsePacmanSlOutput parsea la salida de pacman -Sl
// Formato: "repo name version" o "repo name version [instalado]"
func parsePacmanSlOutput(output string, repo string) ([]Package, error) {
	var packages []Package
	scanner := bufio.NewScanner(strings.NewReader(output))
	
	// Obtener lista de paquetes instalados para verificar estado
	installedPackages, err := GetInstalledPackages()
	if err != nil {
		// Si falla, continuar sin verificar instalación
		installedPackages = []Package{}
	}
	installedMap := make(map[string]bool)
	for _, pkg := range installedPackages {
		installedMap[pkg.Name] = true
	}
	
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		
		// Formato: "repo name version" o "repo name version [instalado]"
		parts := strings.Fields(line)
		if len(parts) < 3 {
			continue
		}
		
		// Verificar que el primer campo sea el repositorio
		if parts[0] != repo {
			continue
		}
		
		name := parts[1]
		version := parts[2]
		
		// Verificar si está instalado (puede estar en parts[3] como "[instalado]")
		installed := installedMap[name]
		if len(parts) >= 4 && (parts[3] == "[instalado]" || parts[3] == "[Installed]") {
			installed = true
		}
		
		pkg := Package{
			Name:        name,
			Version:     version,
			Description: "", // pacman -Sl no incluye descripción
			Repository:  repo,
			Installed:   installed,
		}
		
		packages = append(packages, pkg)
	}
	
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error leyendo salida: %w", err)
	}
	
	return packages, nil
}

// getOrUpdateRepoList obtiene o actualiza la lista de paquetes de un repositorio
// Usa caché de 1 hora
func getOrUpdateRepoList(repo string) ([]Package, error) {
	// Intentar cargar desde archivo
	list, err := loadRepoListFromFile(repo)
	if err == nil {
		// Verificar si la lista tiene menos de 1 hora
		timeSinceUpdate := time.Since(list.LastUpdated)
		if timeSinceUpdate < 1*time.Hour {
			// Usar lista en caché
			return list.Packages, nil
		}
	}
	
	// Necesitamos actualizar la lista
	// Ejecutar pacman -Sl
	cmd := exec.Command("pacman", "-Sl", repo)
	output, err := cmd.Output()
	if err != nil {
		// Si falla, intentar usar lista en caché si existe
		if len(list.Packages) > 0 {
			return list.Packages, nil
		}
		return nil, fmt.Errorf("error ejecutando pacman -Sl %s: %w", repo, err)
	}
	
	// Parsear salida
	packages, err := parsePacmanSlOutput(string(output), repo)
	if err != nil {
		// Si falla el parsing, intentar usar lista en caché si existe
		if list.Packages != nil {
			return list.Packages, nil
		}
		return nil, fmt.Errorf("error parseando salida: %w", err)
	}
	
	// Guardar en archivo
	newList := RepoPackageList{
		LastUpdated: time.Now(),
		Packages:    packages,
	}
	
	if err := saveRepoListToFile(repo, newList); err != nil {
		// Si falla guardar, continuar de todas formas
		// El error se ignora porque ya tenemos los paquetes en memoria
	}
	
	return packages, nil
}

// AURResponse representa la respuesta de la API de AUR
type AURResponse struct {
	Version     int       `json:"version"`
	Type        string    `json:"type"`
	ResultCount int       `json:"resultcount"`
	Results     []AURPkg  `json:"results"`
}

// AURPkg representa un paquete en la respuesta de la API de AUR
type AURPkg struct {
	ID           int     `json:"ID"`
	Name         string  `json:"Name"`
	PackageBase  string  `json:"PackageBase"`
	Version      string  `json:"Version"`
	Description  string  `json:"Description"`
	URL          string  `json:"URL"`
	NumVotes     int     `json:"NumVotes"`
	Popularity   float64 `json:"Popularity"`
	OutOfDate    *int    `json:"OutOfDate"`
	Maintainer   string  `json:"Maintainer"`
	FirstSubmitted int64 `json:"FirstSubmitted"`
	LastModified   int64 `json:"LastModified"`
	URLPath       string `json:"URLPath"`
}

// SearchAURPackages busca paquetes usando la API de AUR v5
func SearchAURPackages(query string) ([]Package, error) {
	// Crear cliente HTTP con timeout
	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	// Construir URL de búsqueda
	baseURL := "https://aur.archlinux.org/rpc/v5/search/"
	searchURL := baseURL + url.QueryEscape(query)

	// Hacer request
	resp, err := client.Get(searchURL)
	if err != nil {
		return nil, fmt.Errorf("error haciendo request a API de AUR: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API de AUR retornó código %d", resp.StatusCode)
	}

	// Leer respuesta
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("error leyendo respuesta: %w", err)
	}

	// Parsear JSON
	var aurResp AURResponse
	if err := json.Unmarshal(body, &aurResp); err != nil {
		return nil, fmt.Errorf("error parseando JSON: %w", err)
	}

	// Obtener lista de paquetes instalados para verificar estado
	installedPackages, err := GetInstalledPackages()
	if err != nil {
		// Si falla, continuar sin verificar instalación
		installedPackages = []Package{}
	}
	installedMap := make(map[string]bool)
	for _, pkg := range installedPackages {
		installedMap[pkg.Name] = true
	}

	// Convertir AURPkg a Package
	packages := make([]Package, 0, len(aurResp.Results))
	for _, aurPkg := range aurResp.Results {
		pkg := Package{
			Name:        aurPkg.Name,
			Version:     aurPkg.Version,
			Description: aurPkg.Description,
			Repository:  "aur",
			Installed:   installedMap[aurPkg.Name],
		}
		packages = append(packages, pkg)
	}

	// Limitar a 500 resultados
	if len(packages) > 500 {
		packages = packages[:500]
	}

	return packages, nil
}

// SearchPackages busca paquetes combinando resultados de AUR, chaotic-aur y multilib
func SearchPackages(query string) ([]Package, error) {
	var allPackages []Package
	
	// Buscar en AUR
	aurPackages, err := SearchAURPackages(query)
	if err == nil {
		allPackages = append(allPackages, aurPackages...)
	}
	
	// Buscar en chaotic-aur
	chaoticPackages, err := getOrUpdateRepoList("chaotic-aur")
	if err == nil {
		// Filtrar localmente
		filtered := FilterPackages(chaoticPackages, query)
		allPackages = append(allPackages, filtered...)
	}
	
	// Buscar en multilib
	multilibPackages, err := getOrUpdateRepoList("multilib")
	if err == nil {
		// Filtrar localmente
		filtered := FilterPackages(multilibPackages, query)
		allPackages = append(allPackages, filtered...)
	}
	
	// Limitar a 500 resultados
	if len(allPackages) > 500 {
		allPackages = allPackages[:500]
	}
	
	return allPackages, nil
}

// InstallProgress representa el progreso de una instalación
type InstallProgress struct {
	PackageName string
	Output      []string
	Done        bool
	Error       error
}

// InstallPackage instala un paquete usando yay -S y emite progreso en tiempo real
// Retorna un canal que emite mensajes de progreso
func InstallPackage(pkgName string, progressChan chan<- InstallProgress) {
	defer close(progressChan)
	
	cmd := exec.Command("yay", "-S", "--noconfirm", pkgName)
	
	// Capturar stdout y stderr por separado
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		progressChan <- InstallProgress{
			PackageName: pkgName,
			Output:      []string{},
			Done:        true,
			Error:       fmt.Errorf("error creando pipe stdout: %w", err),
		}
		return
	}
	
	stderr, err := cmd.StderrPipe()
	if err != nil {
		progressChan <- InstallProgress{
			PackageName: pkgName,
			Output:      []string{},
			Done:        true,
			Error:       fmt.Errorf("error creando pipe stderr: %w", err),
		}
		return
	}
	
	// Iniciar comando
	if err := cmd.Start(); err != nil {
		progressChan <- InstallProgress{
			PackageName: pkgName,
			Output:      []string{},
			Done:        true,
			Error:       fmt.Errorf("error iniciando comando: %w", err),
		}
		return
	}
	
	// Leer salida en tiempo real usando un canal compartido
	lineChan := make(chan string, 100)
	outputDone := make(chan bool, 2)
	var outputLines []string
	
	// Leer stdout
	go func() {
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			lineChan <- scanner.Text()
		}
		outputDone <- true
	}()
	
	// Leer stderr
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			lineChan <- scanner.Text()
		}
		outputDone <- true
	}()
	
	// Recopilar líneas y emitir progreso
	doneCount := 0
	for doneCount < 2 {
		select {
		case line := <-lineChan:
			outputLines = append(outputLines, line)
			progressChan <- InstallProgress{
				PackageName: pkgName,
				Output:      append([]string(nil), outputLines...),
				Done:        false,
				Error:       nil,
			}
		case <-outputDone:
			doneCount++
		}
	}
	
	// Leer cualquier línea restante
	for {
		select {
		case line := <-lineChan:
			outputLines = append(outputLines, line)
			progressChan <- InstallProgress{
				PackageName: pkgName,
				Output:      append([]string(nil), outputLines...),
				Done:        false,
				Error:       nil,
			}
		default:
			goto doneReading
		}
	}
doneReading:
	
	// Esperar a que termine el comando
	if err := cmd.Wait(); err != nil {
		progressChan <- InstallProgress{
			PackageName: pkgName,
			Output:      outputLines,
			Done:        true,
			Error:       fmt.Errorf("error ejecutando comando: %w", err),
		}
		return
	}
	
	// Éxito
	progressChan <- InstallProgress{
		PackageName: pkgName,
		Output:      outputLines,
		Done:        true,
		Error:       nil,
	}
}

// UninstallPackage desinstala un paquete usando yay -Rns y emite progreso en tiempo real
// Retorna un canal que emite mensajes de progreso
func UninstallPackage(pkgName string, progressChan chan<- InstallProgress) {
	defer close(progressChan)
	
	cmd := exec.Command("yay", "-Rns", "--noconfirm", pkgName)
	
	// Capturar stdout y stderr por separado
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		progressChan <- InstallProgress{
			PackageName: pkgName,
			Output:      []string{},
			Done:        true,
			Error:       fmt.Errorf("error creando pipe stdout: %w", err),
		}
		return
	}
	
	stderr, err := cmd.StderrPipe()
	if err != nil {
		progressChan <- InstallProgress{
			PackageName: pkgName,
			Output:      []string{},
			Done:        true,
			Error:       fmt.Errorf("error creando pipe stderr: %w", err),
		}
		return
	}
	
	// Iniciar comando
	if err := cmd.Start(); err != nil {
		progressChan <- InstallProgress{
			PackageName: pkgName,
			Output:      []string{},
			Done:        true,
			Error:       fmt.Errorf("error iniciando comando: %w", err),
		}
		return
	}
	
	// Leer salida en tiempo real usando un canal compartido
	lineChan := make(chan string, 100)
	outputDone := make(chan bool, 2)
	var outputLines []string
	
	// Leer stdout
	go func() {
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			lineChan <- scanner.Text()
		}
		outputDone <- true
	}()
	
	// Leer stderr
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			lineChan <- scanner.Text()
		}
		outputDone <- true
	}()
	
	// Recopilar líneas y emitir progreso
	doneCount := 0
	for doneCount < 2 {
		select {
		case line := <-lineChan:
			outputLines = append(outputLines, line)
			progressChan <- InstallProgress{
				PackageName: pkgName,
				Output:      append([]string(nil), outputLines...),
				Done:        false,
				Error:       nil,
			}
		case <-outputDone:
			doneCount++
		}
	}
	
	// Leer cualquier línea restante
	for {
		select {
		case line := <-lineChan:
			outputLines = append(outputLines, line)
			progressChan <- InstallProgress{
				PackageName: pkgName,
				Output:      append([]string(nil), outputLines...),
				Done:        false,
				Error:       nil,
			}
		default:
			goto doneReading
		}
	}
doneReading:
	
	// Esperar a que termine el comando
	if err := cmd.Wait(); err != nil {
		progressChan <- InstallProgress{
			PackageName: pkgName,
			Output:      outputLines,
			Done:        true,
			Error:       fmt.Errorf("error ejecutando comando: %w", err),
		}
		return
	}
	
	// Éxito
	progressChan <- InstallProgress{
		PackageName: pkgName,
		Output:      outputLines,
		Done:        true,
		Error:       nil,
	}
}

// FilterPackages filtra paquetes basado en una búsqueda flexible por palabras
// Si busco "epson 3251", busca coincidencias que contengan ambas palabras
// en nombre o descripción, no necesariamente en el mismo orden
func FilterPackages(packages []Package, query string) []Package {
	if query == "" {
		return packages
	}

	query = strings.ToLower(strings.TrimSpace(query))
	words := strings.Fields(query)
	
	if len(words) == 0 {
		return packages
	}

	var filtered []Package
	for _, pkg := range packages {
		nameLower := strings.ToLower(pkg.Name)
		descLower := strings.ToLower(pkg.Description)
		
		// Verificar que todas las palabras estén presentes
		allWordsMatch := true
		for _, word := range words {
			if !strings.Contains(nameLower, word) && !strings.Contains(descLower, word) {
				allWordsMatch = false
				break
			}
		}
		
		if allWordsMatch {
			filtered = append(filtered, pkg)
		}
	}

	return filtered
}

