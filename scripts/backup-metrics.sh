#!/bin/bash

# Script de métricas y monitoreo de backup AKS
# Uso: ./backup-metrics.sh

echo "📊 Métricas Completas de Backup AKS"
echo "===================================="
echo "Fecha: $(date)"
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Función para mostrar métricas
show_metric() {
    echo -e "${BLUE}📈 $1:${NC} $2"
}

show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

show_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 1. Estado general del sistema
echo "🔍 Estado General del Sistema"
echo "=============================="

EXTENSION_STATE=$(az k8s-extension show --name azure-aks-backup --cluster-type managedClusters --cluster-name aks-aks-demo-dev --resource-group rg-aks-demo-dev --query "provisioningState" -o tsv 2>/dev/null)
PODS_RUNNING=$(kubectl get pods -n dataprotection-microsoft --no-headers 2>/dev/null | grep Running | wc -l)
BSL_STATUS=$(kubectl get backupstoragelocations default -n dataprotection-microsoft -o jsonpath='{.status.phase}' 2>/dev/null)

show_metric "Extensión AKS" "$EXTENSION_STATE"
show_metric "Pods Running" "$PODS_RUNNING/3"
show_metric "Storage Location" "$BSL_STATUS"
echo ""

# 2. Métricas de backups
echo "📊 Métricas de Backups"
echo "======================"

TOTAL_BACKUPS=$(kubectl get backup.velero.io -n dataprotection-microsoft --no-headers 2>/dev/null | wc -l)
SUCCESS_BACKUPS=$(kubectl get backup.velero.io -n dataprotection-microsoft -o jsonpath='{.items[?(@.status.phase=="Completed")].metadata.name}' 2>/dev/null | wc -w)
FAILED_BACKUPS=$(kubectl get backup.velero.io -n dataprotection-microsoft -o jsonpath='{.items[?(@.status.phase=="Failed")].metadata.name}' 2>/dev/null | wc -w)
PARTIAL_BACKUPS=$(kubectl get backup.velero.io -n dataprotection-microsoft -o jsonpath='{.items[?(@.status.phase=="PartiallyFailed")].metadata.name}' 2>/dev/null | wc -w)

if [ $TOTAL_BACKUPS -gt 0 ]; then
    SUCCESS_RATE=$((SUCCESS_BACKUPS * 100 / TOTAL_BACKUPS))
else
    SUCCESS_RATE=0
fi

show_metric "Total Backups" "$TOTAL_BACKUPS"
show_metric "Exitosos" "$SUCCESS_BACKUPS"
show_metric "Fallidos" "$FAILED_BACKUPS"
show_metric "Parciales" "$PARTIAL_BACKUPS"
show_metric "Success Rate" "$SUCCESS_RATE%"
echo ""

# 3. Schedules y automatización
echo "📅 Schedules y Automatización"
echo "============================="

SCHEDULES=$(kubectl get schedules -n dataprotection-microsoft --no-headers 2>/dev/null | wc -l)
ENABLED_SCHEDULES=$(kubectl get schedules -n dataprotection-microsoft -o jsonpath='{.items[?(@.status.phase=="Enabled")].metadata.name}' 2>/dev/null | wc -w)

show_metric "Schedules Configurados" "$SCHEDULES"
show_metric "Schedules Activos" "$ENABLED_SCHEDULES"

if [ $SCHEDULES -gt 0 ]; then
    echo "Schedules disponibles:"
    kubectl get schedules -n dataprotection-microsoft --no-headers 2>/dev/null | while read name schedule status; do
        echo "  - $name: $schedule ($status)"
    done
fi
echo ""

# 4. Últimos backups
echo "🕒 Últimos Backups"
echo "=================="

echo "Backups más recientes:"
kubectl get backup.velero.io -n dataprotection-microsoft --sort-by=.metadata.creationTimestamp --no-headers 2>/dev/null | tail -5 | while read name phase age; do
    case $phase in
        "Completed") echo -e "  ${GREEN}✅${NC} $name ($phase) - $age" ;;
        "Failed") echo -e "  ${RED}❌${NC} $name ($phase) - $age" ;;
        "PartiallyFailed") echo -e "  ${YELLOW}⚠️${NC} $name ($phase) - $age" ;;
        "InProgress") echo -e "  ${BLUE}🔄${NC} $name ($phase) - $age" ;;
        *) echo "  📦 $name ($phase) - $age" ;;
    esac
done
echo ""

# 5. Uso de almacenamiento
echo "💾 Uso de Almacenamiento"
echo "========================"

# Obtener información del storage location
STORAGE_INFO=$(kubectl describe backupstoragelocations default -n dataprotection-microsoft 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "Storage Location Details:"
    echo "$STORAGE_INFO" | grep -E "(Bucket|Last Validated Time|Phase)" | sed 's/^/  /'
else
    show_error "No se pudo obtener información de almacenamiento"
fi
echo ""

# 6. Alertas y recomendaciones
echo "🚨 Alertas y Recomendaciones"
echo "============================"

# Verificar alertas
ALERTS=0

if [ "$EXTENSION_STATE" != "Succeeded" ]; then
    show_error "Extensión AKS no está en estado Succeeded"
    ((ALERTS++))
fi

if [ $PODS_RUNNING -lt 3 ]; then
    show_error "No todos los pods de backup están running ($PODS_RUNNING/3)"
    ((ALERTS++))
fi

if [ "$BSL_STATUS" != "Available" ]; then
    show_error "BackupStorageLocation no está Available"
    ((ALERTS++))
fi

if [ $SUCCESS_RATE -lt 80 ] && [ $TOTAL_BACKUPS -gt 0 ]; then
    show_warning "Success rate bajo: $SUCCESS_RATE% (recomendado >80%)"
    ((ALERTS++))
fi

if [ $FAILED_BACKUPS -gt 2 ]; then
    show_warning "Múltiples backups fallidos: $FAILED_BACKUPS"
    ((ALERTS++))
fi

if [ $SCHEDULES -eq 0 ]; then
    show_warning "No hay schedules automáticos configurados"
    ((ALERTS++))
fi

if [ $ALERTS -eq 0 ]; then
    show_success "Sistema de backup funcionando correctamente"
else
    show_warning "Se encontraron $ALERTS alertas que requieren atención"
fi
echo ""

# 7. Comandos útiles
echo "🔧 Comandos Útiles"
echo "=================="
echo "# Ver todos los backups:"
echo "kubectl get backup.velero.io -n dataprotection-microsoft"
echo ""
echo "# Crear backup manual:"
echo "kubectl apply -f - <<EOF"
echo "apiVersion: velero.io/v1"
echo "kind: Backup"
echo "metadata:"
echo "  name: manual-backup-\$(date +%Y%m%d-%H%M%S)"
echo "  namespace: dataprotection-microsoft"
echo "spec:"
echo "  includedNamespaces: [\"default\"]"
echo "  storageLocation: default"
echo "  ttl: 168h0m0s"
echo "EOF"
echo ""
echo "# Ver logs de Velero:"
echo "kubectl logs -n dataprotection-microsoft -l app.kubernetes.io/name=velero"
echo ""
echo "# Validar configuración completa:"
echo "./scripts/validate-azure-native-backup.sh"

# 8. Resumen final
echo ""
echo "📋 Resumen Ejecutivo"
echo "===================="
if [ $SUCCESS_RATE -ge 90 ] && [ "$BSL_STATUS" = "Available" ] && [ $PODS_RUNNING -eq 3 ]; then
    show_success "Sistema de backup en estado ÓPTIMO"
elif [ $SUCCESS_RATE -ge 70 ] && [ "$BSL_STATUS" = "Available" ]; then
    show_warning "Sistema de backup en estado BUENO con mejoras menores"
else
    show_error "Sistema de backup requiere ATENCIÓN INMEDIATA"
fi

echo "Próxima ejecución de métricas recomendada: $(date -d '+1 day' '+%Y-%m-%d %H:%M')"
