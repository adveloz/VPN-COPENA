# Seguridad - VPN Platform

## Resumen de medidas de seguridad

Esta plataforma implementa múltiples capas de seguridad para proteger tu VPN personal.

---

## 1. Firewall (UFW)

### Configuración recomendada

```bash
# Instalar UFW si no está instalado
sudo apt install ufw -y

# Resetear reglas existentes
sudo ufw reset

# Política por defecto
sudo ufw default deny incoming    # Denegar todo tráfico entrante
sudo ufw default allow outgoing   # Permitir todo tráfico saliente

# Permitir SSH (para no perder acceso al servidor)
sudo ufw allow 22/tcp comment "SSH"

# Permitir WireGuard VPN
sudo ufw allow 51820/udp comment "WireGuard VPN"

# Permitir HTTP y HTTPS (Traefik)
sudo ufw allow 80/tcp comment "HTTP - Traefik"
sudo ufw allow 443/tcp comment "HTTPS - Traefik"

# Activar firewall
sudo ufw enable

# Verificar reglas
sudo ufw status numbered
```

### IP forwarding para VPN

```bash
# Activar IP forwarding permanentemente
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Verificar
sysctl net.ipv4.ip_forward
```

---

## 2. Fail2Ban

### Cómo funciona

Fail2Ban monitorea los logs de Traefik y banea automáticamente IPs que muestran comportamiento malicioso:

- **traefik-auth**: Detecta intentos fallidos de autenticación (401/403). Después de 5 intentos en 5 minutos, banea la IP por 1 hora.
- **traefik-botsearch**: Detecta escaneos de vulnerabilidades (intentos de acceder a wp-login, phpmyadmin, .env, .git, etc.). Después de 10 intentos, banea por 10 minutos.

### Archivos de configuración

```
config/fail2ban/
├── jail.local                 # Configuración global
├── jail.d/
│   └── traefik.conf           # Jails específicos para Traefik
└── filter.d/
    ├── traefik-auth.conf      # Regex para detectar auth fallida
    └── traefik-botsearch.conf # Regex para detectar escaneo de bots
```

### Comandos útiles

```bash
# Ver IPs baneadas
docker exec fail2ban fail2ban-client status traefik-auth
docker exec fail2ban fail2ban-client status traefik-botsearch

# Desbanear una IP específica
docker exec fail2ban fail2ban-client set traefik-auth unbanip 1.2.3.4

# Ver logs de fail2ban
docker logs fail2ban
```

---

## 3. Seguridad de WireGuard

### Mejores prácticas

- **Protocolo**: WireGuard usa criptografía moderna (ChaCha20, Poly1305, Curve25519, BLAKE2)
- **Superficie de ataque mínima**: Solo un puerto UDP abierto (51820)
- **Claves únicas**: Cada cliente tiene su propio par de claves
- **Kill switch**: Los clientes pueden configurar `AllowedIPs = 0.0.0.0/0` para enrutar TODO el tráfico por el VPN

### Recomendaciones

1. Usa contraseñas fuertes para el panel de wg-easy (mínimo 16 caracteres)
2. Revisa periódicamente los clientes conectados y elimina los que no uses
3. No compartas archivos de configuración por canales inseguros

---

## 4. HTTPS y TLS

- Traefik genera certificados SSL automáticamente con Let's Encrypt
- TLS 1.2 como versión mínima (TLS 1.0 y 1.1 desactivados)
- Cipher suites fuertes configurados en `traefik/dynamic.yml`
- HSTS activado (fuerza HTTPS por 1 año)
- Headers de seguridad: X-Frame-Options, X-Content-Type-Options, X-XSS-Protection

---

## 5. Seguridad de Docker

### Buenas prácticas implementadas

- Docker socket montado como solo lectura (`:ro`)
- Servicios con `restart: unless-stopped`
- Capacidades mínimas (`NET_ADMIN`, `SYS_MODULE` solo donde es necesario)
- Red aislada entre contenedores
- Volúmenes nombrados para persistencia

### Recomendaciones adicionales

```bash
# Mantener Docker actualizado
sudo apt update && sudo apt upgrade docker-ce -y

# Verificar que Docker no permite acceso sin sudo a usuarios no autorizados
# Solo usuarios en el grupo 'docker' pueden ejecutar contenedores
groups $USER
```

---

## 6. Rotación de credenciales

### Cambiar contraseña de wg-easy

1. Edita el archivo `.env`:
   ```bash
   nano .env
   # Cambia WG_ADMIN_PASSWORD=NuevaContraseñaSegura!
   ```
2. Reinicia el servicio:
   ```bash
   docker compose up -d wg-easy
   ```

### Cambiar contraseña de Pi-hole

1. Edita el archivo `.env`:
   ```bash
   nano .env
   # Cambia PIHOLE_PASSWORD=NuevaContraseñaPiHole!
   ```
2. Reinicia el servicio:
   ```bash
   docker compose up -d pihole
   ```

### Regenerar claves WireGuard de un cliente

1. En el panel `vpn.tudominio.com`, elimina el cliente
2. Crea uno nuevo con el mismo nombre
3. Descarga la nueva configuración y actualízala en el dispositivo

### Renovar certificados SSL

Los certificados Let's Encrypt se renuevan automáticamente. Si necesitas forzar la renovación:

```bash
# Eliminar certificados actuales
docker volume rm traefik-certs

# Recrear Traefik
docker compose up -d traefik
```

---

## 7. Monitoreo de seguridad

### Logs a revisar periódicamente

```bash
# Logs de Traefik (accesos HTTP)
docker compose logs traefik | tail -100

# Logs de Fail2Ban (IPs baneadas)
docker logs fail2ban | tail -50

# Logs de WireGuard
docker compose logs wg-easy | tail -50

# Conexiones activas en el servidor
ss -tunlp
```

### Configurar monitoreo en Uptime Kuma

1. Accede a `https://status.tudominio.com`
2. Crea monitores para:
   - `https://vpn.tudominio.com` (panel WireGuard)
   - `https://dns.tudominio.com` (panel Pi-hole)
   - `https://status.tudominio.com` (auto-monitoreo)
   - `tudominio.com:51820` (puerto WireGuard, tipo TCP)

---

## 8. Checklist de seguridad

- [ ] Cambiar todas las contraseñas por defecto en `.env`
- [ ] Configurar UFW con las reglas recomendadas
- [ ] Verificar que IP forwarding está activado
- [ ] Comprobar que los certificados HTTPS se generan correctamente
- [ ] Crear solo los clientes VPN necesarios
- [ ] Configurar monitoreo en Uptime Kuma
- [ ] Programar backups automáticos con cron
- [ ] Cambiar el puerto SSH por defecto (opcional pero recomendado)
- [ ] Desactivar login por contraseña en SSH (usar solo claves)
