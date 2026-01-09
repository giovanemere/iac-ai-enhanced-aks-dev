#!/bin/bash

# Script de backup antes de destruir cluster
# Uso: ./pre-destroy-backup.sh [CLUSTER_NAME] [RESOURCE_GROUP]

set -e

CLUSTER_NAME=${1:-"aks-aks-demo-dev"}
RESOURCE_GROUP=${2:-"rg-aks-demo-dev"}

echo "🛡️ Backup Pre-Destrucción del Cluster"
echo "======================================"
echo "Cluster: $CLUSTER_NAME"
echo "Resource Group: $RESOURCE_GROUP"
echo "Fecha: $(date)"
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

show_step() {
    echo -e "${YELLOW}📋 $1${NC}"
}

show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

show_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Verificar acceso al cluster
show_step "Verificando acceso al cluster..."
if ! kubectl cluster-info > /dev/null 2>&1; then
    show_error "No se puede acceder al cluster. Verificar kubectl config."
    exit 1
fi
show_success "Acceso al cluster verificado"

# Verificar si Velero está instalado
show_step "Verificando instalación de Velero..."
if ! kubectl get namespace dataprotection-microsoft > /dev/null 2>&1; then
    show_error "Velero no está instalado. No se puede realizar backup."
    exit 1
fi
show_success "Velero encontrado"

# Crear backup completo pre-destrucción
show_step "Creando backup completo pre-destrucción..."
BACKUP_NAME="pre-destroy-backup-$(date +%Y%m%d-%H%M%S)"

kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: $BACKUP_NAME
  namespace: dataprotection-microsoft
  labels:
    backup-type: pre-destroy
    cluster: $CLUSTER_NAME
spec:
  includedNamespaces:
  - "*"
  excludedNamespaces:
  - kube-system
  - dataprotection-microsoft
  - kube-public
  - kube-node-lease
  excludedResources:
  - events
  - events.events.k8s.io
  - nodes
  storageLocation: default
  volumeSnapshotLocations:
  - default
  ttl: 2160h0m0s  # 90 días
  snapshotVolumes: true
  includeClusterResources: true
EOF

show_success "Backup '$BACKUP_NAME' iniciado"

# Esperar a que el backup complete
show_step "Esperando completación del backup..."
TIMEOUT=1800  # 30 minutos
ELAPSED=0
INTERVAL=30

while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(kubectl get backup.velero.io $BACKUP_NAME -n dataprotection-microsoft -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    
    case $STATUS in
        "Completed")
            show_success "Backup completado exitosamente"
            break
            ;;
        "Failed")
            show_error "Backup falló"
            kubectl describe backup.velero.io $BACKUP_NAME -n dataprotection-microsoft
            exit 1
            ;;
        "PartiallyFailed")
            show_error "Backup completado con errores parciales"
            kubectl describe backup.velero.io $BACKUP_NAME -n dataprotection-microsoft
            break
            ;;
        "InProgress")
            echo "⏳ Backup en progreso... ($ELAPSED/$TIMEOUT segundos)"
            ;;
        *)
            echo "🔄 Estado: $STATUS ($ELAPSED/$TIMEOUT segundos)"
            ;;
    esac
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    show_error "Timeout esperando completación del backup"
    exit 1
fi

# Verificar detalles del backup
show_step "Verificando detalles del backup..."
ITEMS_BACKED_UP=$(kubectl get backup.velero.io $BACKUP_NAME -n dataprotection-microsoft -o jsonpath='{.status.progress.itemsBackedUp}' 2>/dev/null || echo "0")
TOTAL_ITEMS=$(kubectl get backup.velero.io $BACKUP_NAME -n dataprotection-microsoft -o jsonpath='{.status.progress.totalItems}' 2>/dev/null || echo "0")

echo "📊 Resumen del backup:"
echo "├── Nombre: $BACKUP_NAME"
echo "├── Items respaldados: $ITEMS_BACKED_UP/$TOTAL_ITEMS"
echo "├── Retención: 90 días"
echo "└── Ubicación: Azure Storage"

# Guardar información del backup para restauración
BACKUP_INFO_FILE="/tmp/cluster-backup-info.txt"
cat > $BACKUP_INFO_FILE << EOF
# Información de backup pre-destrucción
BACKUP_NAME=$BACKUP_NAME
CLUSTER_NAME=$CLUSTER_NAME
RESOURCE_GROUP=$RESOURCE_GROUP
BACKUP_DATE=$(date)
ITEMS_BACKED_UP=$ITEMS_BACKED_UP
TOTAL_ITEMS=$TOTAL_ITEMS
STORAGE_ACCOUNT=$(kubectl get backupstoragelocations default -n dataprotection-microsoft -o jsonpath='{.spec.config.storageAccount}' 2>/dev/null || echo "Unknown")
EOF

show_success "Información de backup guardada en: $BACKUP_INFO_FILE"

echo ""
echo "🎉 BACKUP PRE-DESTRUCCIÓN COMPLETADO"
echo "===================================="
echo ""
echo "✅ Backup creado: $BACKUP_NAME"
echo "✅ Items respaldados: $ITEMS_BACKED_UP/$TOTAL_ITEMS"
echo "✅ Retención: 90 días"
echo "✅ Información guardada: $BACKUP_INFO_FILE"
echo ""
echo "🔄 Comandos para restauración después de recrear cluster:"
echo "1. Configurar backup: ./scripts/complete-backup-setup.sh"
echo "2. Restaurar datos: ./scripts/post-create-restore.sh $BACKUP_NAME"
echo ""
echo "⚠️  IMPORTANTE: Guardar el nombre del backup: $BACKUP_NAME"
