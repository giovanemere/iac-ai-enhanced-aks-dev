#!/bin/bash

# Script de restauración automática post-creación
# Uso: ./ai-restore.sh [BACKUP_NAME]

set -e

BACKUP_NAME=${1}
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🤖 AI Restore - Restauración Automática"
echo "======================================="

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  [INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅ [SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️  [WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}❌ [ERROR]${NC} $1"
}

log_ai() {
    echo -e "${PURPLE}🤖 [AI-AGENT]${NC} $1"
}

# Verificar si hay información de backup previo
if [ -z "$BACKUP_NAME" ]; then
    if [ -f "$PROJECT_ROOT/.backup-info" ]; then
        source "$PROJECT_ROOT/.backup-info"
        BACKUP_NAME="$LAST_BACKUP_NAME"
        log_info "Usando backup automático: $BACKUP_NAME"
    else
        log_error "No se especificó backup y no hay información de backup previo"
        echo "Uso: $0 <BACKUP_NAME>"
        echo "O ejecutar después de ai-orchestrator.sh redeploy"
        exit 1
    fi
fi

# Verificar acceso al cluster
log_info "Verificando acceso al cluster..."
if ! kubectl cluster-info > /dev/null 2>&1; then
    log_error "No se puede acceder al cluster"
    exit 1
fi

# Verificar que Velero esté configurado
log_info "Verificando sistema de backup..."
if ! kubectl get namespace dataprotection-microsoft > /dev/null 2>&1; then
    log_error "Sistema de backup no configurado. Ejecutar: ./scripts/complete-backup-setup.sh"
    exit 1
fi

# Verificar que el backup existe
log_info "Verificando backup: $BACKUP_NAME"
if ! kubectl get backup.velero.io "$BACKUP_NAME" -n dataprotection-microsoft > /dev/null 2>&1; then
    log_error "Backup no encontrado: $BACKUP_NAME"
    echo "Backups disponibles:"
    kubectl get backup.velero.io -n dataprotection-microsoft --no-headers | awk '{print "  - " $1}'
    exit 1
fi

# Verificar estado del backup
BACKUP_STATUS=$(kubectl get backup.velero.io "$BACKUP_NAME" -n dataprotection-microsoft -o jsonpath='{.status.phase}')
if [ "$BACKUP_STATUS" != "Completed" ] && [ "$BACKUP_STATUS" != "PartiallyFailed" ]; then
    log_error "Backup no está en estado válido para restauración: $BACKUP_STATUS"
    exit 1
fi

# Crear restauración
RESTORE_NAME="ai-restore-$(date +%Y%m%d-%H%M%S)"
log_ai "Creando restauración: $RESTORE_NAME"

kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: $RESTORE_NAME
  namespace: dataprotection-microsoft
  labels:
    restore-type: ai-automatic
    source-backup: $BACKUP_NAME
spec:
  backupName: $BACKUP_NAME
  includedNamespaces: ["default"]
  excludedResources: ["events", "events.events.k8s.io"]
  restorePVs: true
  preserveNodePorts: false
EOF

log_success "Restauración iniciada: $RESTORE_NAME"

# Monitorear progreso de restauración
log_info "Monitoreando progreso de restauración..."
TIMEOUT=1800  # 30 minutos
ELAPSED=0
INTERVAL=30

while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(kubectl get restore.velero.io $RESTORE_NAME -n dataprotection-microsoft -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    
    case $STATUS in
        "Completed")
            log_success "Restauración completada exitosamente"
            break
            ;;
        "Failed")
            log_error "Restauración falló"
            kubectl describe restore.velero.io $RESTORE_NAME -n dataprotection-microsoft
            exit 1
            ;;
        "PartiallyFailed")
            log_warning "Restauración completada con errores parciales"
            break
            ;;
        "InProgress")
            echo "⏳ Restauración en progreso... ($ELAPSED/$TIMEOUT segundos)"
            ;;
        *)
            echo "🔄 Estado: $STATUS ($ELAPSED/$TIMEOUT segundos)"
            ;;
    esac
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    log_error "Timeout esperando completación de la restauración"
    exit 1
fi

# Verificar recursos restaurados
log_info "Verificando recursos restaurados..."
RESTORED_ITEMS=$(kubectl get restore.velero.io $RESTORE_NAME -n dataprotection-microsoft -o jsonpath='{.status.progress.itemsRestored}' 2>/dev/null || echo "0")
TOTAL_ITEMS=$(kubectl get restore.velero.io $RESTORE_NAME -n dataprotection-microsoft -o jsonpath='{.status.progress.totalItems}' 2>/dev/null || echo "0")

echo ""
echo "🎉 RESTAURACIÓN COMPLETADA"
echo "=========================="
echo "✅ Restauración: $RESTORE_NAME"
echo "✅ Backup origen: $BACKUP_NAME"
echo "✅ Items restaurados: $RESTORED_ITEMS/$TOTAL_ITEMS"
echo ""

# Verificar pods en namespace default
log_info "Verificando pods restaurados..."
PODS=$(kubectl get pods -n default --no-headers 2>/dev/null | wc -l)
if [ $PODS -gt 0 ]; then
    log_success "$PODS pods encontrados en namespace default"
    kubectl get pods -n default
else
    log_warning "No se encontraron pods en namespace default"
fi

echo ""
log_ai "Restauración automática completada exitosamente"
