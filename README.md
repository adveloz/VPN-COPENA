# 🔒 VPN Platform - Tu VPN Personal

Plataforma VPN privada completa con bloqueo de anuncios, HTTPS automático y monitoreo. Diseñada para desplegarse en una VPS con Docker y Dockploy.

## Arquitectura

```
┌─────────────────────────────────────────────────┐
│                   INTERNET                       │
└────────────┬──────────┬──────────┬──────────────┘
             │          │          │
        :51820/udp   :80/tcp   :443/tcp
             │          │          │
┌────────────┴──────────┴──────────┴──────────────┐
│                    VPS (Brasil)                   │
│                                                   │
│  ┌──────────┐    ┌─────────────────────────┐     │
│  │ WireGuard│    │       Traefik            │     │
│  │ :51820   │    │  (Reverse Proxy + HTTPS) │     │
│  └─────┬────┘    └────┬──────┬──────┬───────┘     │
│        │              │      │      │             │
│        ▼              ▼      ▼      ▼             │
│  ┌──────────┐  ┌────────┐┌─────┐┌────────┐      │
│  │ Pi-hole  │  │wg-easy ││Pi-  ││Uptime  │      │
│  │ DNS      │  │UI      ││hole ││Kuma    │      │
│  │10.8.1.100│  │        ││UI   ││        │      │
│  └──────────┘  └────────┘└─────┘└────────┘      │
│                                                   │
│  ┌──────────┐                                     │
│  │ Fail2Ban │ (Protección contra ataques)         │
│  └──────────┘                                     │
└───────────────────────────────────────────────────┘
```

**Flujo de tráfico VPN:**
```
Cliente → WireGuard → Pi-hole (filtrado DNS) → Internet
```

## Servicios

| Servicio | Función | Acceso |
|----------|---------|--------|
| **WireGuard** (wg-easy) | VPN + Panel de administración | `vpn.tudominio.com` |
| **Pi-hole** | DNS con bloqueo de anuncios | `dns.tudominio.com` |
| **Uptime Kuma** | Monitoreo de servicios | `status.tudominio.com` |
| **Traefik** | Reverse proxy + HTTPS | Interno |
| **Fail2Ban** | Protección contra fuerza bruta | Interno |

## Puertos expuestos

| Puerto | Protocolo | Servicio |
|--------|-----------|----------|
| 51820 | UDP | WireGuard VPN |
| 80 | TCP | HTTP (redirige a HTTPS) |
| 443 | TCP | HTTPS |

---

## Despliegue

### Opción 1: Despliegue con Dockploy

1. **Subir repositorio a GitHub**
   ```bash
   cd vpn-platform
   git init
   git add .
   git commit -m "Initial commit: VPN platform"
   git remote add origin https://github.com/TU_USUARIO/vpn-platform.git
   git push -u origin main
   ```

2. **En Dockploy:**
   - Ve a tu panel de Dockploy en tu VPS
   - Haz clic en **"Create Project"** → **"Compose"**
   - Selecciona **"GitHub"** como fuente
   - Conecta tu repositorio `vpn-platform`
   - En la sección de **Environment Variables**, agrega todas las variables del `.env.example` con tus valores reales
   - Haz clic en **"Deploy"**

3. **Configurar variables de entorno en Dockploy:**
   ```
   SERVER_DOMAIN=tudominio.com
   ADMIN_EMAIL=tu@email.com
   WG_HOST=tudominio.com
   WG_PORT=51820
   WG_DEFAULT_DNS=10.8.1.100
   WG_ALLOWED_IPS=0.0.0.0/0, ::/0
   WG_ADMIN_PASSWORD=TuContraseñaSegura123!
   PIHOLE_PASSWORD=TuContraseñaPiHole123!
   TIMEZONE=America/Sao_Paulo
   ```

> **Nota sobre Dockploy:** Asegúrate de que Dockploy no esté usando los puertos 80/443, o configura Traefik para usar puertos alternativos si hay conflicto.

### Opción 2: Despliegue manual con Docker

1. **Conectarse al servidor:**
   ```bash
   ssh root@IP_DE_TU_VPS
   ```

2. **Instalar Docker (si no está instalado):**
   ```bash
   curl -fsSL https://get.docker.com | sh
   ```

3. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/TU_USUARIO/vpn-platform.git
   cd vpn-platform
   ```

4. **Configurar variables de entorno:**
   ```bash
   cp .env.example .env
   nano .env
   # Edita todas las variables con tus valores reales
   ```

5. **Habilitar IP forwarding en el host:**
   ```bash
   echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
   sysctl -p
   ```

6. **Iniciar los servicios:**
   ```bash
   docker compose up -d
   ```

7. **Verificar que todo funciona:**
   ```bash
   docker compose ps
   docker compose logs -f
   ```

---

## Configuración DNS

Necesitas crear los siguientes registros DNS apuntando a la IP de tu VPS:

| Tipo | Nombre | Valor |
|------|--------|-------|
| A | `vpn.tudominio.com` | `IP_DE_TU_VPS` |
| A | `dns.tudominio.com` | `IP_DE_TU_VPS` |
| A | `status.tudominio.com` | `IP_DE_TU_VPS` |

Esto se configura en el panel de tu proveedor de dominios (Cloudflare, Namecheap, GoDaddy, etc).

> **Si usas Cloudflare:** Desactiva el proxy (nube naranja → nube gris) para que el tráfico llegue directamente a tu VPS. El SSL lo maneja Traefik con Let's Encrypt.

---

## Crear y conectar clientes VPN

### Crear un nuevo cliente

1. Accede a `https://vpn.tudominio.com`
2. Ingresa la contraseña de administración
3. Haz clic en **"New Client"**
4. Dale un nombre (ej: "mi-telefono", "mi-laptop")
5. Descarga el archivo de configuración (`.conf`) o escanea el código QR

### Conectar desde Android

1. Instala [WireGuard desde Google Play](https://play.google.com/store/apps/details?id=com.wireguard.android)
2. Abre la app → toca el botón **"+"**
3. Selecciona **"Escanear código QR"**
4. Escanea el QR desde el panel `vpn.tudominio.com`
5. Activa el túnel VPN

### Conectar desde iOS (iPhone/iPad)

1. Instala [WireGuard desde App Store](https://apps.apple.com/app/wireguard/id1441195209)
2. Abre la app → toca **"Agregar un túnel"**
3. Selecciona **"Crear desde código QR"**
4. Escanea el QR desde el panel `vpn.tudominio.com`
5. Activa el túnel VPN

### Conectar desde macOS

1. Instala [WireGuard desde App Store](https://apps.apple.com/app/wireguard/id1451685025) o con Homebrew:
   ```bash
   brew install wireguard-tools
   ```
2. **Con la app:** Importa el archivo `.conf` descargado
3. **Con terminal:**
   ```bash
   # Copiar archivo de configuración
   sudo cp mi-laptop.conf /etc/wireguard/wg0.conf
   
   # Activar VPN
   sudo wg-quick up wg0
   
   # Desactivar VPN
   sudo wg-quick down wg0
   ```

### Conectar desde Windows

1. Descarga [WireGuard para Windows](https://www.wireguard.com/install/)
2. Instala y abre la app
3. Haz clic en **"Importar túnel desde archivo"**
4. Selecciona el archivo `.conf` descargado
5. Haz clic en **"Activar"**

### Conectar desde Linux

```bash
# Instalar WireGuard
sudo apt install wireguard   # Debian/Ubuntu
sudo dnf install wireguard   # Fedora

# Copiar configuración
sudo cp mi-dispositivo.conf /etc/wireguard/wg0.conf

# Activar VPN
sudo wg-quick up wg0

# Desactivar VPN
sudo wg-quick down wg0

# Activar VPN automáticamente al iniciar
sudo systemctl enable wg-quick@wg0
```

---

## Administración

### Ver estado de los servicios
```bash
docker compose ps
```

### Ver logs en tiempo real
```bash
# Todos los servicios
docker compose logs -f

# Un servicio específico
docker compose logs -f wg-easy
docker compose logs -f pihole
docker compose logs -f traefik
```

### Reiniciar un servicio
```bash
docker compose restart wg-easy
```

### Actualizar todos los servicios
```bash
./scripts/update.sh
```

### Crear backup
```bash
./scripts/backup.sh
```

### Parar todos los servicios
```bash
docker compose down
```

---

## Firewall (UFW)

Configura el firewall del servidor para solo permitir tráfico necesario:

```bash
# Resetear reglas
sudo ufw reset

# Política por defecto: denegar todo
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Permitir SSH (¡importante para no perder acceso!)
sudo ufw allow 22/tcp

# Permitir WireGuard
sudo ufw allow 51820/udp

# Permitir HTTP y HTTPS (Traefik)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Activar firewall
sudo ufw enable

# Verificar reglas
sudo ufw status verbose
```

---

## Estructura del proyecto

```
vpn-platform/
├── docker-compose.yml          # Definición de todos los servicios
├── .env.example                # Variables de entorno de ejemplo
├── .gitignore                  # Archivos a ignorar en Git
├── README.md                   # Esta documentación
├── traefik/
│   ├── traefik.yml             # Configuración estática de Traefik
│   └── dynamic.yml             # Middlewares y configuración TLS
├── config/
│   ├── wireguard/              # Configs de WireGuard (auto-generadas)
│   ├── pihole/
│   │   └── custom-dnsmasq.conf # Configuración DNS personalizada
│   └── fail2ban/
│       ├── jail.local          # Configuración general de jails
│       ├── jail.d/
│       │   └── traefik.conf    # Jail específico para Traefik
│       └── filter.d/
│           ├── traefik-auth.conf      # Filtro de autenticación
│           └── traefik-botsearch.conf # Filtro de escaneo de bots
├── scripts/
│   ├── backup.sh               # Script de backup automático
│   └── update.sh               # Script de actualización
└── docs/
    ├── architecture.md         # Documentación de arquitectura
    ├── security.md             # Guía de seguridad
    └── deployment.md           # Guía detallada de despliegue
```

## Licencia

Uso personal. No distribuir credenciales ni archivos de configuración con datos reales.
