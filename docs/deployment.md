# Guía de Despliegue - VPN Platform

Guía paso a paso para desplegar la plataforma VPN en tu VPS.

---

## Prerrequisitos

- VPS con Ubuntu 22.04+ (o Debian 12+)
- Mínimo 1 GB RAM, 1 vCPU
- IP pública estática
- Dominio con acceso a configuración DNS
- Dockploy ya instalado en la VPS (para opción Dockploy)

---

## Paso 1: Preparar el servidor

```bash
# Conectarse al servidor
ssh root@IP_DE_TU_VPS

# Actualizar sistema
apt update && apt upgrade -y

# Instalar Docker (si no está instalado)
curl -fsSL https://get.docker.com | sh

# Verificar Docker
docker --version
docker compose version

# Habilitar IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

---

## Paso 2: Configurar DNS

En el panel de tu proveedor de dominios, crea estos registros **A**:

| Tipo | Nombre | Valor | TTL |
|------|--------|-------|-----|
| A | `vpn` | `IP_DE_TU_VPS` | 300 |
| A | `dns` | `IP_DE_TU_VPS` | 300 |
| A | `status` | `IP_DE_TU_VPS` | 300 |

> Espera unos minutos para que propaguen. Verifica con:
> ```bash
> dig vpn.tudominio.com +short
> dig dns.tudominio.com +short
> dig status.tudominio.com +short
> ```

---

## Paso 3: Configurar firewall

```bash
sudo ufw allow 22/tcp
sudo ufw allow 51820/udp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

---

## Paso 4A: Despliegue con Dockploy

### 4A.1 Subir a GitHub

En tu máquina local:

```bash
cd vpn-platform
git init
git add .
git commit -m "VPN platform initial setup"
git remote add origin https://github.com/TU_USUARIO/vpn-platform.git
git branch -M main
git push -u origin main
```

### 4A.2 Configurar en Dockploy

1. Accede al panel de Dockploy de tu VPS
2. Ve a **Projects** → **Create Project**
3. Dale un nombre: `vpn-platform`
4. Dentro del proyecto, haz clic en **"+ Create Service"** → **"Compose"**
5. Selecciona **"GitHub"** como fuente
6. Conecta tu cuenta de GitHub si no lo has hecho
7. Busca y selecciona el repositorio `vpn-platform`
8. En la rama, selecciona `main`

### 4A.3 Configurar variables de entorno

En la sección **"Environment"** de Dockploy, agrega:

```env
SERVER_DOMAIN=tudominio.com
ADMIN_EMAIL=tu@email.com
WG_HOST=tudominio.com
WG_PORT=51820
WG_DEFAULT_DNS=10.8.1.100
WG_ALLOWED_IPS=0.0.0.0/0, ::/0
WG_ADMIN_PASSWORD=TuContraseñaMuySegura2024!
PIHOLE_PASSWORD=OtraContraseñaSegura2024!
TIMEZONE=America/Sao_Paulo
```

### 4A.4 Consideraciones con Dockploy

**Conflicto de puertos:** Si Dockploy ya usa los puertos 80/443 con su propio Traefik:

- **Opción 1:** Usar el Traefik de Dockploy en lugar del de este proyecto. Elimina el servicio `traefik` del `docker-compose.yml` y configura los labels para usar la red de Dockploy.
- **Opción 2:** Configurar Dockploy para usar puertos alternativos y dejar este Traefik en 80/443.

### 4A.5 Desplegar

1. Haz clic en **"Deploy"**
2. Espera a que todos los contenedores estén activos
3. Verifica en los logs que no hay errores

---

## Paso 4B: Despliegue manual

### 4B.1 Clonar y configurar

```bash
# En el servidor
cd /opt
git clone https://github.com/TU_USUARIO/vpn-platform.git
cd vpn-platform

# Configurar variables de entorno
cp .env.example .env
nano .env
# Edita TODAS las variables con tus valores reales
```

### 4B.2 Iniciar servicios

```bash
docker compose up -d
```

### 4B.3 Verificar

```bash
# Estado de contenedores
docker compose ps

# Logs en tiempo real
docker compose logs -f

# Verificar que WireGuard escucha
ss -tunlp | grep 51820
```

---

## Paso 5: Verificación post-despliegue

### Verificar HTTPS

```bash
# Debe retornar código 200
curl -I https://vpn.tudominio.com
curl -I https://dns.tudominio.com
curl -I https://status.tudominio.com
```

### Verificar WireGuard

```bash
# Debe mostrar el contenedor activo
docker compose ps wg-easy
```

### Verificar Pi-hole

```bash
# Resolver un dominio a través de Pi-hole
dig @10.8.1.100 google.com
```

---

## Paso 6: Crear primer cliente VPN

1. Abre `https://vpn.tudominio.com` en tu navegador
2. Ingresa la contraseña (`WG_ADMIN_PASSWORD`)
3. Haz clic en **"+ New"**
4. Escribe un nombre para el cliente (ej: "mi-telefono")
5. Aparecerá un código QR y un botón de descarga
6. Escanea el QR desde la app WireGuard en tu dispositivo

### Probar la conexión

1. Activa el VPN en tu dispositivo
2. Ve a [https://whatismyipaddress.com](https://whatismyipaddress.com) — debe mostrar la IP de tu VPS en Brasil
3. Ve a [https://ads-blocker.com/testing/](https://ads-blocker.com/testing/) — debe mostrar que los anuncios están bloqueados

---

## Paso 7: Configurar monitoreo

1. Abre `https://status.tudominio.com`
2. Crea una cuenta de administrador
3. Agrega estos monitores:
   - **WireGuard Panel**: `https://vpn.tudominio.com` (HTTP)
   - **Pi-hole Panel**: `https://dns.tudominio.com` (HTTP)
   - **WireGuard Port**: `tudominio.com:51820` (TCP)

---

## Paso 8: Programar backups automáticos

```bash
# Dar permisos de ejecución
chmod +x /opt/vpn-platform/scripts/backup.sh
chmod +x /opt/vpn-platform/scripts/update.sh

# Programar backup diario a las 3:00 AM
crontab -e

# Agregar esta línea:
0 3 * * * /opt/vpn-platform/scripts/backup.sh >> /var/log/vpn-backup.log 2>&1
```

---

## Solución de problemas

### Los certificados HTTPS no se generan

```bash
# Verificar logs de Traefik
docker compose logs traefik

# Causas comunes:
# - DNS no apunta a la IP correcta
# - Puerto 80 bloqueado por firewall
# - Otro servicio usando el puerto 80
```

### WireGuard no conecta

```bash
# Verificar que el puerto UDP está abierto
sudo ufw status | grep 51820

# Verificar que el contenedor está activo
docker compose ps wg-easy

# Verificar IP forwarding
sysctl net.ipv4.ip_forward
```

### Pi-hole no bloquea anuncios

```bash
# Verificar que los clientes VPN usan Pi-hole como DNS
# En el panel de wg-easy, verifica que DNS = 10.8.1.100

# Verificar que Pi-hole está activo
docker compose ps pihole
docker compose logs pihole
```

### No puedo acceder a los paneles web

```bash
# Verificar que Traefik está corriendo
docker compose ps traefik
docker compose logs traefik

# Verificar resolución DNS
dig vpn.tudominio.com

# Verificar que los puertos están abiertos
ss -tunlp | grep -E "80|443"
```
