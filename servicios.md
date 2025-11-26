# Gestión de Servicios Systemd

Este documento contiene instrucciones para activar servicios que fueron deshabilitados del inicio automático.

## Servicios Deshabilitados

Los siguientes servicios fueron deshabilitados para mejorar el tiempo de arranque:
- Docker (docker.service, containerd.service)
- Bluetooth (bluetooth.service)
- Impresión CUPS (cups.service)
- Cloudflared (cloudflared.service)

**Tiempo ahorrado:** ~900ms en el arranque

---

## Cómo Activar Servicios Cuando Los Necesites

### Docker

**Iniciar Docker temporalmente:**
```bash
sudo systemctl start docker
```

**Verificar estado:**
```bash
sudo systemctl status docker
```

**Re-habilitar en el arranque (si lo necesitas permanentemente):**
```bash
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
```

---

### Bluetooth

**Iniciar Bluetooth temporalmente:**
```bash
sudo systemctl start bluetooth
```

**Verificar estado:**
```bash
sudo systemctl status bluetooth
```

**Re-habilitar en el arranque:**
```bash
sudo systemctl enable bluetooth.service
```

---

### Impresión (CUPS)

**Iniciar servicio de impresión temporalmente:**
```bash
sudo systemctl start cups
```

**Verificar estado:**
```bash
sudo systemctl status cups
```

**Re-habilitar en el arranque:**
```bash
sudo systemctl enable cups.service
sudo systemctl enable cups.socket
```

---

### Cloudflared

**Iniciar Cloudflared temporalmente:**
```bash
sudo systemctl start cloudflared
```

**Verificar estado:**
```bash
sudo systemctl status cloudflared
```

**Re-habilitar en el arranque:**
```bash
sudo systemctl enable cloudflared.service
```

---

## Comandos Útiles

**Ver todos los servicios habilitados:**
```bash
systemctl list-unit-files --type=service --state=enabled
```

**Ver tiempo de arranque de servicios:**
```bash
systemd-analyze blame
```

**Ver servicios en ejecución:**
```bash
systemctl list-units --type=service --state=running
```

**Detener un servicio en ejecución:**
```bash
sudo systemctl stop <nombre-servicio>
```

---

## Notas

- Los servicios iniciados con `start` se detendrán al reiniciar el sistema
- NetworkManager, systemd-resolved y alsa-restore NO fueron deshabilitados (necesarios para internet y multimedia)
- Para cambios permanentes usa `enable`/`disable`
- Para cambios temporales usa `start`/`stop`
