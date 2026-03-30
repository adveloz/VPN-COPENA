# Arquitectura - VPN Platform

## Visión general

Esta plataforma implementa una VPN personal completa que enruta todo el tráfico de los clientes a través de un servidor WireGuard, filtrando DNS con Pi-hole para bloquear anuncios y rastreadores.

## Diagrama de red

```
                        INTERNET
                           │
            ┌──────────────┼──────────────┐
            │              │              │
       :51820/udp       :80/tcp       :443/tcp
            │              │              │
╔═══════════╧══════════════╧══════════════╧═══════════════╗
║                      VPS HOST                            ║
║                                                          ║
║  ┌─────────────────────────────────────────────────────┐ ║
║  │              Docker Network: 10.8.1.0/24            │ ║
║  │                                                     │ ║
║  │  ┌───────────────┐     ┌──────────────────────┐    │ ║
║  │  │   WireGuard   │     │      Traefik         │    │ ║
║  │  │   wg-easy     │     │   Reverse Proxy      │    │ ║
║  │  │  10.8.1.2     │     │   + Let's Encrypt    │    │ ║
║  │  │  :51820/udp   │     │   :80 → :443         │    │ ║
║  │  └───────┬───────┘     └──────┬───┬───┬───────┘    │ ║
║  │          │                    │   │   │             │ ║
║  │          ▼                    │   │   │             │ ║
║  │  ┌───────────────┐          │   │   │              │ ║
║  │  │   Pi-hole     │◄─────────┘   │   │             │ ║
║  │  │   DNS Server  │  vpn.dom ─────┘   │             │ ║
║  │  │  10.8.1.100   │  dns.dom ─────────┘             │ ║
║  │  │  :53 (DNS)    │  status.dom ─┐                  │ ║
║  │  └───────────────┘              │                  │ ║
║  │                                 ▼                  │ ║
║  │                    ┌──────────────────┐            │ ║
║  │                    │   Uptime Kuma    │            │ ║
║  │                    │   Monitoreo      │            │ ║
║  │                    │   :3001          │            │ ║
║  │                    └──────────────────┘            │ ║
║  │                                                     │ ║
║  └─────────────────────────────────────────────────────┘ ║
║                                                          ║
║  ┌──────────────────┐                                    ║
║  │    Fail2Ban      │  (host network mode)               ║
║  │    Protección    │                                    ║
║  └──────────────────┘                                    ║
╚══════════════════════════════════════════════════════════╝
```

## Flujo de tráfico VPN

1. El cliente WireGuard inicia una conexión al puerto `51820/udp` del servidor
2. El túnel VPN se establece y todo el tráfico del cliente se enruta por el túnel
3. Las consultas DNS del cliente se envían a Pi-hole (`10.8.1.100`)
4. Pi-hole filtra anuncios/rastreadores y reenvía consultas legítimas a DNS upstream (Cloudflare `1.1.1.1`)
5. El tráfico web sale a Internet desde la IP del servidor VPS

## Componentes

### WireGuard (wg-easy)
- Protocolo VPN moderno, rápido y seguro
- Panel web para crear/gestionar clientes
- Genera automáticamente configuraciones y códigos QR
- Red interna: `10.8.0.0/24` para clientes VPN

### Pi-hole
- Servidor DNS que filtra dominios de publicidad y rastreadores
- Listas de bloqueo actualizadas automáticamente
- Panel web con estadísticas de consultas DNS
- También bloquea malware y phishing a nivel DNS

### Traefik
- Reverse proxy que maneja todo el tráfico HTTP/HTTPS
- Genera certificados SSL automáticamente con Let's Encrypt
- Enruta subdominios a servicios internos
- Redirige HTTP → HTTPS automáticamente

### Fail2Ban
- Monitorea logs de Traefik para detectar ataques
- Banea IPs que hacen demasiados intentos fallidos
- Protege contra escaneo de vulnerabilidades

### Uptime Kuma
- Dashboard para monitorear el estado de todos los servicios
- Alertas cuando un servicio se cae
- Historial de uptime

## Red Docker

Todos los servicios comparten la red Docker `vpn-network` con subred `10.8.1.0/24`:

| Servicio | IP | Puertos internos |
|----------|-----|------------------|
| wg-easy | 10.8.1.2 | 51820/udp, 51821/tcp |
| Pi-hole | 10.8.1.100 | 53/tcp, 53/udp, 80/tcp |
| Traefik | DHCP | 80, 443 |
| Uptime Kuma | DHCP | 3001 |
| Fail2Ban | Host network | - |

## Volúmenes de datos

| Volumen | Contenido |
|---------|-----------|
| `wg-easy-data` | Claves y configuraciones WireGuard |
| `pihole-data` | Base de datos y configuración Pi-hole |
| `pihole-dnsmasq` | Configuración dnsmasq |
| `traefik-certs` | Certificados Let's Encrypt |
| `uptime-kuma-data` | Base de datos de monitoreo |
