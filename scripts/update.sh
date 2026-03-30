#!/bin/bash
# =============================================================================
# VPN Platform - Script de Actualización
# =============================================================================
# Actualiza todas las imágenes Docker y reinicia los servicios.
#
# Uso:
#   chmod +x scripts/update.sh
#   ./scripts/update.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "================================================"
echo "  VPN Platform - Actualización"
echo "  Fecha: $(date)"
echo "================================================"

cd "$PROJECT_DIR"

# ---------------------------------------------------------------------------
# Paso 1: Crear backup antes de actualizar
# ---------------------------------------------------------------------------
echo ""
echo "[1/4] Creando backup de seguridad..."
if [ -f "$SCRIPT_DIR/backup.sh" ]; then
    bash "$SCRIPT_DIR/backup.sh"
else
    echo "  AVISO: Script de backup no encontrado, continuando sin backup"
fi

# ---------------------------------------------------------------------------
# Paso 2: Descargar últimas imágenes
# ---------------------------------------------------------------------------
echo ""
echo "[2/4] Descargando últimas imágenes Docker..."
docker compose pull

# ---------------------------------------------------------------------------
# Paso 3: Reiniciar servicios con nuevas imágenes
# ---------------------------------------------------------------------------
echo ""
echo "[3/4] Reiniciando servicios..."
docker compose up -d --remove-orphans

# ---------------------------------------------------------------------------
# Paso 4: Limpiar imágenes antiguas
# ---------------------------------------------------------------------------
echo ""
echo "[4/4] Limpiando imágenes no utilizadas..."
docker image prune -f

# ---------------------------------------------------------------------------
# Verificar estado
# ---------------------------------------------------------------------------
echo ""
echo "================================================"
echo "  Estado de los servicios:"
echo "================================================"
docker compose ps

echo ""
echo "================================================"
echo "  Actualización completada"
echo "================================================"
