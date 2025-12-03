package jobs

import (
	"fmt"
	"net/http"
	"time"

	"orgmos/internal/logger"
)

// HealthcheckClient maneja las notificaciones a healthchecks
type HealthcheckClient struct {
	baseURL string
	client  *http.Client
}

// NewHealthcheckClient crea un nuevo cliente de healthchecks
func NewHealthcheckClient(baseURL string) *HealthcheckClient {
	return &HealthcheckClient{
		baseURL: baseURL,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// Ping envía un ping de healthcheck
func (hc *HealthcheckClient) Ping(healthcheckID string) error {
	return hc.pingEndpoint(healthcheckID, "")
}

// PingStart envía un ping de inicio
func (hc *HealthcheckClient) PingStart(healthcheckID string) error {
	return hc.pingEndpoint(healthcheckID, "/start")
}

// PingFail envía un ping de fallo
func (hc *HealthcheckClient) PingFail(healthcheckID string) error {
	return hc.pingEndpoint(healthcheckID, "/fail")
}

// pingEndpoint envía una petición HTTP HEAD al endpoint de healthcheck
func (hc *HealthcheckClient) pingEndpoint(healthcheckID string, suffix string) error {
	url := fmt.Sprintf("%s/ping/%s%s", hc.baseURL, healthcheckID, suffix)
	
	logger.Info("Enviando healthcheck: %s", url)
	
	resp, err := hc.client.Head(url)
	if err != nil {
		logger.Warn("Error enviando healthcheck a %s: %v", url, err)
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		logger.Info("Healthcheck enviado exitosamente: %s (status: %d)", url, resp.StatusCode)
		return nil
	}

	logger.Warn("Healthcheck retornó status inesperado: %s (status: %d)", url, resp.StatusCode)
	return fmt.Errorf("healthcheck retornó status %d", resp.StatusCode)
}








