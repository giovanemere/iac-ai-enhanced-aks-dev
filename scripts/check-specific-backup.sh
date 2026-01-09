#!/bin/bash

# Script para verificar estado de backup específico desde portal Azure
# Uso: ./check-specific-backup.sh [JOB_ID]

JOB_ID=${1:-"f6ac73bd-ba52-427a-a7c1-d1c1e09f5063"}

echo "🔍 Verificación de Backup Específico"
echo "===================================="
echo "Job ID: $JOB_ID"
echo "Portal: https://portal.azure.com/#view/Microsoft_Azure_DataProtection/JobDetailsBlade/jobId/%2Fsubscriptions%2F617fad55-504d-42d2-ba0e-267e8472a399%2FresourceGroups%2Frg-aks-demo-dev%2Fproviders%2FMicrosoft.DataProtection%2FbackupVaults%2Fbv-aks-aks-demo-dev%2FbackupJobs%2F$JOB_ID"
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📊 1. Estado del Job en Azure DataProtection:${NC}"
JOB_STATUS=$(az dataprotection job show \
  --resource-group rg-aks-demo-dev \
  --vault-name bv-aks-aks-demo-dev \
  --job-id "$JOB_ID" \
  --query "status" -o tsv 2>/dev/null)

if [ -n "$JOB_STATUS" ]; then
    echo "Estado del Job: $JOB_STATUS"
    az dataprotection job show \
      --resource-group rg-aks-demo-dev \
      --vault-name bv-aks-aks-demo-dev \
      --job-id "$JOB_ID" \
      --query "{Status:status,StartTime:startTime,EndTime:endTime,BackupInstance:backupInstanceName}" \
      -o table 2>/dev/null
else
    echo "Job no encontrado o completado (normal para jobs antiguos)"
fi

echo ""
echo -e "${BLUE}📦 2. Backups de Velero (últimos 5):${NC}"
kubectl get backup.velero.io -n dataprotection-microsoft --sort-by=.metadata.creationTimestamp | tail -5

echo ""
echo -e "${BLUE}🔍 3. Backup más reciente (posiblemente el solicitado):${NC}"
LATEST_BACKUP=$(kubectl get backup.velero.io -n dataprotection-microsoft --sort-by=.metadata.creationTimestamp --no-headers | tail -1 | awk '{print $1}')
echo "Nombre: $LATEST_BACKUP"

if [ -n "$LATEST_BACKUP" ]; then
    echo ""
    echo -e "${BLUE}📋 4. Detalles del backup:${NC}"
    
    STATUS=$(kubectl get backup.velero.io "$LATEST_BACKUP" -n dataprotection-microsoft -o jsonpath='{.status.phase}' 2>/dev/null)
    START_TIME=$(kubectl get backup.velero.io "$LATEST_BACKUP" -n dataprotection-microsoft -o jsonpath='{.status.startTimestamp}' 2>/dev/null)
    END_TIME=$(kubectl get backup.velero.io "$LATEST_BACKUP" -n dataprotection-microsoft -o jsonpath='{.status.completionTimestamp}' 2>/dev/null)
    ITEMS_BACKED=$(kubectl get backup.velero.io "$LATEST_BACKUP" -n dataprotection-microsoft -o jsonpath='{.status.progress.itemsBackedUp}' 2>/dev/null)
    TOTAL_ITEMS=$(kubectl get backup.velero.io "$LATEST_BACKUP" -n dataprotection-microsoft -o jsonpath='{.status.progress.totalItems}' 2>/dev/null)
    SNAPSHOTS=$(kubectl get backup.velero.io "$LATEST_BACKUP" -n dataprotection-microsoft -o jsonpath='{.status.csiVolumeSnapshotsCompleted}' 2>/dev/null)
    
    echo "├── Estado: $STATUS"
    echo "├── Inicio: $START_TIME"
    echo "├── Fin: $END_TIME"
    echo "├── Items respaldados: $ITEMS_BACKED/$TOTAL_ITEMS"
    echo "└── Volume Snapshots: $SNAPSHOTS completados"
    
    # Calcular duración si ambos timestamps existen
    if [ -n "$START_TIME" ] && [ -n "$END_TIME" ]; then
        START_EPOCH=$(date -d "$START_TIME" +%s 2>/dev/null)
        END_EPOCH=$(date -d "$END_TIME" +%s 2>/dev/null)
        if [ -n "$START_EPOCH" ] && [ -n "$END_EPOCH" ]; then
            DURATION=$((END_EPOCH - START_EPOCH))
            echo "    Duración: $DURATION segundos"
        fi
    fi
    
    echo ""
    echo -e "${BLUE}🔧 5. Comandos útiles:${NC}"
    echo "# Ver detalles completos:"
    echo "kubectl describe backup.velero.io \"$LATEST_BACKUP\" -n dataprotection-microsoft"
    echo ""
    echo "# Ver configuración del backup:"
    echo "kubectl get backup.velero.io \"$LATEST_BACKUP\" -n dataprotection-microsoft -o yaml"
    echo ""
    echo "# Ver volume snapshots:"
    echo "kubectl get volumesnapshot -A"
fi

echo ""
echo -e "${BLUE}📊 6. Resumen del sistema de backup:${NC}"
TOTAL_BACKUPS=$(kubectl get backup.velero.io -n dataprotection-microsoft --no-headers 2>/dev/null | wc -l)
COMPLETED_BACKUPS=$(kubectl get backup.velero.io -n dataprotection-microsoft -o jsonpath='{.items[?(@.status.phase=="Completed")].metadata.name}' 2>/dev/null | wc -w)
FAILED_BACKUPS=$(kubectl get backup.velero.io -n dataprotection-microsoft -o jsonpath='{.items[?(@.status.phase=="Failed")].metadata.name}' 2>/dev/null | wc -w)

echo "├── Total de backups: $TOTAL_BACKUPS"
echo "├── Completados: $COMPLETED_BACKUPS"
echo "├── Fallidos: $FAILED_BACKUPS"

if [ $TOTAL_BACKUPS -gt 0 ]; then
    SUCCESS_RATE=$(( COMPLETED_BACKUPS * 100 / TOTAL_BACKUPS ))
    echo "└── Success rate: $SUCCESS_RATE%"
else
    echo "└── Success rate: N/A"
fi

echo ""
if [ "$STATUS" = "Completed" ]; then
    echo -e "${GREEN}✅ Backup verificado exitosamente${NC}"
elif [ "$STATUS" = "Failed" ]; then
    echo -e "${RED}❌ Backup falló - revisar logs${NC}"
elif [ "$STATUS" = "InProgress" ]; then
    echo -e "${YELLOW}🔄 Backup en progreso${NC}"
else
    echo -e "${YELLOW}ℹ️  Estado del backup: $STATUS${NC}"
fi
