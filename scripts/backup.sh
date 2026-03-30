#!/bin/bash
# =============================================================================
# VPN Platform - Script de Backup
# =============================================================================
# Crea un backup completo de todos los datos de la plataforma VPN.
#
# Uso:
#   chmod +x scripts/backup.sh
#   ./scripts/backup.sh
#
# Programar backup diario con cron:
#   crontab -e
#   0 3 * * * /ruta/al/proyecto/scripts/backup.sh
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuración
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/vpn-backup-${TIMESTAMP}.tar.gz"

# Número de backups a mantener (los más antiguos se eliminan)
MAX_BACKUPS=7

# ---------------------------------------------------------------------------
# Crear directorio de backups
# ---------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR"

echo "================================================"
echo "  VPN Platform - Backup"
echo "  Fecha: $(date)"
echo "================================================"

# ---------------------------------------------------------------------------
# Detener servicios temporalmente para consistencia de datos
# ---------------------------------------------------------------------------
echo ""
echo "[1/4] Deteniendo servicios temporalmente..."
cd "$PROJECT_DIR"
docker compose stop wg-easy pihole uptime-kuma 2>/dev/null || true

# ---------------------------------------------------------------------------
# Crear backup de volúmenes Docker
# ---------------------------------------------------------------------------
echo "[2/4] Creando backup de datos..."

# Directorio temporal para recolectar datos
TEMP_DIR=$(mktemp -d)

# Backup de configuración WireGuard
docker run --rm -v wg-easy-data:/data -v "$TEMP_DIR":/backup alpine \
    tar czf /backup/wireguard.tar.gz -C /data . 2>/dev/null || echo "  AVISO: No se pudo respaldar WireGuard"

# Backup de Pi-hole
docker run --rm -v pihole-data:/data -v "$TEMP_DIR":/backup alpine \
    tar czf /backup/pihole-data.tar.gz -C /data . 2>/dev/null || echo "  AVISO: No se pudo respaldar Pi-hole data"

docker run --rm -v pihole-dnsmasq:/data -v "$TEMP_DIR":/backup alpine \
    tar czf /backup/pihole-dnsmasq.tar.gz -C /data . 2>/dev/null || echo "  AVISO: No se pudo respaldar Pi-hole dnsmasq"

# Backup de Uptime Kuma
docker run --rm -v uptime-kuma-data:/data -v "$TEMP_DIR":/backup alpine \
    tar czf /backup/uptime-kuma.tar.gz -C /data . 2>/dev/null || echo "  AVISO: No se pudo respaldar Uptime Kuma"

# Backup de certificados Traefik
docker run --rm -v traefik-certs:/data -v "$TEMP_DIR":/backup alpine \
    tar czf /backup/traefik-certs.tar.gz -C /data . 2>/dev/null || echo "  AVISO: No se pudo respaldar certificados"

# Backup de archivos de configuración del proyecto
cp -r "$PROJECT_DIR/.env" "$TEMP_DIR/dot-env" 2>/dev/null || true
cp -r "$PROJECT_DIR/traefik" "$TEMP_DIR/traefik-config" 2>/dev/null || true
cp -r "$PROJECT_DIR/config" "$TEMP_DIR/config" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Comprimir todo en un solo archivo
# ---------------------------------------------------------------------------
echo "[3/4] Comprimiendo backup..."
tar czf "$BACKUP_FILE" -C "$TEMP_DIR" .
rm -rf "$TEMP_DIR"

# ---------------------------------------------------------------------------
# Reiniciar servicios
# ---------------------------------------------------------------------------
echo "[4/4] Reiniciando servicios..."
cd "$PROJECT_DIR"
docker compose start wg-easy pihole uptime-kuma 2>/dev/null || true

# ---------------------------------------------------------------------------
# Limpiar backups antiguos
# ---------------------------------------------------------------------------
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "vpn-backup-*.tar.gz" | wc -l)
if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
    echo ""
    echo "Limpiando backups antiguos (manteniendo últimos $MAX_BACKUPS)..."
    find "$BACKUP_DIR" -name "vpn-backup-*.tar.gz" -type f | \
        sort | head -n -"$MAX_BACKUPS" | xargs rm -f
fi

# ---------------------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------------------
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo ""
echo "================================================"
echo "  Backup completado exitosamente"
echo "  Archivo: $BACKUP_FILE"
echo "  Tamaño: $BACKUP_SIZE"
echo "================================================"
