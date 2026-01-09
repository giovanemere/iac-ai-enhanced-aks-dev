#!/bin/bash

# Script de validación para Backup Nativo de Azure
# Uso: ./validate-azure-native-backup.sh [RESOURCE_GROUP] [CLUSTER_NAME] [VAULT_NAME]

set -e

# Configuración por defecto
RESOURCE_GROUP=${1:-"rg-aks-demo-dev"}
CLUSTER_NAME=${2:-"aks-aks-demo-dev"}
VAULT_NAME=${3:-"bv-aks-aks-demo-dev"}

echo "🔍 Validación de Backup Nativo Azure"
echo "===================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Cluster: $CLUSTER_NAME"
echo "Vault: $VAULT_NAME"
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar resultado
show_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

# Función para mostrar warning
show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Función para mostrar info
show_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo "1. Verificando acceso a Azure y cluster..."
# Verificar Azure CLI
az account show --query "name" -o tsv > /dev/null 2>&1
show_result $? "Azure CLI autenticado"

# Verificar kubectl
kubectl cluster-info --request-timeout=10s > /dev/null 2>&1
show_result $? "Acceso al cluster AKS"

echo ""
echo "2. Verificando extensiones de Azure CLI..."
# Verificar extensión k8s-extension
K8S_EXT=$(az extension list --query "[?name=='k8s-extension'].version" -o tsv 2>/dev/null)
if [ -n "$K8S_EXT" ]; then
    show_result 0 "Extensión k8s-extension ($K8S_EXT)"
else
    show_result 1 "Extensión k8s-extension no instalada"
fi

# Verificar extensión dataprotection
DP_EXT=$(az extension list --query "[?name=='dataprotection'].version" -o tsv 2>/dev/null)
if [ -n "$DP_EXT" ]; then
    show_result 0 "Extensión dataprotection ($DP_EXT)"
else
    show_result 1 "Extensión dataprotection no instalada"
fi

echo ""
echo "3. Verificando Backup Vault..."
VAULT_EXISTS=$(az dataprotection backup-vault show \
    --resource-group $RESOURCE_GROUP \
    --vault-name $VAULT_NAME \
    --query "name" -o tsv 2>/dev/null)

if [ "$VAULT_EXISTS" = "$VAULT_NAME" ]; then
    show_result 0 "Backup Vault existe: $VAULT_NAME"
    
    # Verificar identidad del vault
    VAULT_IDENTITY=$(az dataprotection backup-vault show \
        --resource-group $RESOURCE_GROUP \
        --vault-name $VAULT_NAME \
        --query "identity.type" -o tsv 2>/dev/null)
    show_info "Identidad del vault: $VAULT_IDENTITY"
else
    show_result 1 "Backup Vault no encontrado"
fi

echo ""
echo "4. Verificando extensión AKS Backup..."
EXTENSION_STATE=$(az k8s-extension show \
    --name azure-aks-backup \
    --cluster-type managedClusters \
    --cluster-name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --query "provisioningState" -o tsv 2>/dev/null)

if [ "$EXTENSION_STATE" = "Succeeded" ]; then
    show_result 0 "Extensión AKS Backup: $EXTENSION_STATE"
    
    # Obtener configuración
    STORAGE_ACCOUNT=$(az k8s-extension show \
        --name azure-aks-backup \
        --cluster-type managedClusters \
        --cluster-name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --query "configurationSettings.\"configuration.backupStorageLocation.config.storageAccount\"" -o tsv 2>/dev/null)
    show_info "Storage Account: $STORAGE_ACCOUNT"
    
    # Obtener Principal ID
    PRINCIPAL_ID=$(az k8s-extension show \
        --name azure-aks-backup \
        --cluster-type managedClusters \
        --cluster-name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --query "aksAssignedIdentity.principalId" -o tsv 2>/dev/null)
    show_info "Principal ID: $PRINCIPAL_ID"
else
    show_result 1 "Extensión AKS Backup: $EXTENSION_STATE"
fi

echo ""
echo "5. Verificando permisos de Storage..."
if [ -n "$PRINCIPAL_ID" ] && [ -n "$STORAGE_ACCOUNT" ]; then
    STORAGE_ACCOUNT_ID="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"
    
    ROLE_ASSIGNMENTS=$(az role assignment list \
        --assignee $PRINCIPAL_ID \
        --scope $STORAGE_ACCOUNT_ID \
        --query "length(@)" 2>/dev/null)
    
    if [ "$ROLE_ASSIGNMENTS" -gt 0 ]; then
        show_result 0 "Permisos Storage Account ($ROLE_ASSIGNMENTS asignaciones)"
        
        # Verificar rol específico
        BLOB_CONTRIBUTOR=$(az role assignment list \
            --assignee $PRINCIPAL_ID \
            --scope $STORAGE_ACCOUNT_ID \
            --query "[?roleDefinitionName=='Storage Blob Data Contributor'].roleDefinitionName" -o tsv 2>/dev/null)
        
        if [ -n "$BLOB_CONTRIBUTOR" ]; then
            show_info "Rol Storage Blob Data Contributor: ✅"
        else
            show_warning "Rol Storage Blob Data Contributor no encontrado"
        fi
    else
        show_result 1 "Sin permisos en Storage Account"
    fi
else
    show_warning "No se pueden verificar permisos (falta Principal ID o Storage Account)"
fi

echo ""
echo "6. Verificando pods de backup..."
NAMESPACE_EXISTS=$(kubectl get namespace dataprotection-microsoft --no-headers 2>/dev/null | wc -l)
if [ $NAMESPACE_EXISTS -gt 0 ]; then
    show_result 0 "Namespace dataprotection-microsoft existe"
    
    # Contar pods
    TOTAL_PODS=$(kubectl get pods -n dataprotection-microsoft --no-headers 2>/dev/null | wc -l)
    RUNNING_PODS=$(kubectl get pods -n dataprotection-microsoft --no-headers 2>/dev/null | grep Running | wc -l)
    
    if [ $RUNNING_PODS -eq $TOTAL_PODS ] && [ $TOTAL_PODS -ge 3 ]; then
        show_result 0 "Pods de backup ($RUNNING_PODS/$TOTAL_PODS running)"
    else
        show_result 1 "Pods de backup ($RUNNING_PODS/$TOTAL_PODS running)"
        
        # Mostrar pods con problemas
        echo "   Pods con problemas:"
        kubectl get pods -n dataprotection-microsoft --no-headers | grep -v Running | awk '{print "   - " $1 ": " $3}'
    fi
else
    show_result 1 "Namespace dataprotection-microsoft no existe"
fi

echo ""
echo "7. Verificando BackupStorageLocation..."
BSL_STATUS=$(kubectl get backupstoragelocations default -n dataprotection-microsoft -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$BSL_STATUS" = "Available" ]; then
    show_result 0 "BackupStorageLocation: $BSL_STATUS"
    
    # Verificar última validación
    LAST_VALIDATED=$(kubectl get backupstoragelocations default -n dataprotection-microsoft -o jsonpath='{.status.lastValidationTime}' 2>/dev/null)
    show_info "Última validación: $LAST_VALIDATED"
else
    show_result 1 "BackupStorageLocation: $BSL_STATUS"
fi

echo ""
echo "8. Verificando VolumeSnapshotLocation..."
VSL_COUNT=$(kubectl get volumesnapshotlocations -n dataprotection-microsoft --no-headers 2>/dev/null | wc -l)
if [ $VSL_COUNT -gt 0 ]; then
    show_result 0 "VolumeSnapshotLocation configurado ($VSL_COUNT)"
else
    show_result 1 "VolumeSnapshotLocation no configurado"
fi

echo ""
echo "9. Verificando políticas de backup..."
POLICY_COUNT=$(az dataprotection backup-policy list \
    --resource-group $RESOURCE_GROUP \
    --vault-name $VAULT_NAME \
    --query "length(@)" 2>/dev/null)

if [ "$POLICY_COUNT" -gt 0 ]; then
    show_result 0 "Políticas de backup ($POLICY_COUNT)"
    
    # Listar políticas
    echo "   Políticas disponibles:"
    az dataprotection backup-policy list \
        --resource-group $RESOURCE_GROUP \
        --vault-name $VAULT_NAME \
        --query "[].name" -o tsv 2>/dev/null | sed 's/^/   - /'
else
    show_result 1 "Sin políticas de backup configuradas"
fi

echo ""
echo "10. Verificando backups existentes..."
BACKUP_COUNT=$(kubectl get backup.velero.io -n dataprotection-microsoft --no-headers 2>/dev/null | wc -l)
if [ $BACKUP_COUNT -gt 0 ]; then
    show_result 0 "Backups existentes ($BACKUP_COUNT)"
    
    # Mostrar últimos backups
    echo "   Últimos backups:"
    kubectl get backup.velero.io -n dataprotection-microsoft --sort-by=.metadata.creationTimestamp --no-headers 2>/dev/null | tail -3 | awk '{print "   - " $1 ": " $2 " (" $4 ")"}'
    
    # Verificar backups completados
    COMPLETED_BACKUPS=$(kubectl get backup.velero.io -n dataprotection-microsoft -o jsonpath='{.items[?(@.status.phase=="Completed")].metadata.name}' 2>/dev/null | wc -w)
    show_info "Backups completados: $COMPLETED_BACKUPS"
else
    show_warning "Sin backups existentes"
fi

echo ""
echo "11. Verificando schedules automáticos..."
SCHEDULE_COUNT=$(kubectl get schedules -n dataprotection-microsoft --no-headers 2>/dev/null | wc -l)
if [ $SCHEDULE_COUNT -gt 0 ]; then
    show_result 0 "Schedules automáticos ($SCHEDULE_COUNT)"
    
    # Mostrar schedules
    echo "   Schedules configurados:"
    kubectl get schedules -n dataprotection-microsoft --no-headers 2>/dev/null | awk '{print "   - " $1 ": " $2}'
else
    show_info "Sin schedules automáticos (solo backups manuales)"
fi

echo ""
echo "📊 Resumen de Validación:"
echo "========================"

# Calcular score
TOTAL_CHECKS=11
PASSED_CHECKS=0

# Rerun checks silently for scoring
az account show > /dev/null 2>&1 && ((PASSED_CHECKS++))
kubectl cluster-info --request-timeout=5s > /dev/null 2>&1 && ((PASSED_CHECKS++))
[ -n "$(az extension list --query "[?name=='k8s-extension'].version" -o tsv 2>/dev/null)" ] && ((PASSED_CHECKS++))
[ -n "$(az extension list --query "[?name=='dataprotection'].version" -o tsv 2>/dev/null)" ] && ((PASSED_CHECKS++))
[ "$(az dataprotection backup-vault show --resource-group $RESOURCE_GROUP --vault-name $VAULT_NAME --query "name" -o tsv 2>/dev/null)" = "$VAULT_NAME" ] && ((PASSED_CHECKS++))
[ "$(az k8s-extension show --name azure-aks-backup --cluster-type managedClusters --cluster-name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query "provisioningState" -o tsv 2>/dev/null)" = "Succeeded" ] && ((PASSED_CHECKS++))
[ $(kubectl get namespace dataprotection-microsoft --no-headers 2>/dev/null | wc -l) -gt 0 ] && ((PASSED_CHECKS++))
[ "$(kubectl get backupstoragelocations default -n dataprotection-microsoft -o jsonpath='{.status.phase}' 2>/dev/null)" = "Available" ] && ((PASSED_CHECKS++))
[ $(kubectl get volumesnapshotlocations -n dataprotection-microsoft --no-headers 2>/dev/null | wc -l) -gt 0 ] && ((PASSED_CHECKS++))
[ $(az dataprotection backup-policy list --resource-group $RESOURCE_GROUP --vault-name $VAULT_NAME --query "length(@)" 2>/dev/null) -gt 0 ] && ((PASSED_CHECKS++))
[ $(kubectl get backup.velero.io -n dataprotection-microsoft --no-headers 2>/dev/null | wc -l) -ge 0 ] && ((PASSED_CHECKS++))

SCORE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

echo "Score: $PASSED_CHECKS/$TOTAL_CHECKS ($SCORE%)"

if [ $SCORE -ge 90 ]; then
    echo -e "${GREEN}🎉 Backup nativo Azure completamente funcional${NC}"
elif [ $SCORE -ge 70 ]; then
    echo -e "${YELLOW}⚠️  Backup nativo Azure funcional con mejoras menores${NC}"
elif [ $SCORE -ge 50 ]; then
    echo -e "${YELLOW}⚠️  Backup nativo Azure parcialmente funcional${NC}"
else
    echo -e "${RED}❌ Backup nativo Azure requiere configuración significativa${NC}"
fi

echo ""
echo "🔧 Comandos útiles:"
echo "   # Ver estado de backups"
echo "   kubectl get backup.velero.io -n dataprotection-microsoft"
echo ""
echo "   # Crear backup manual"
echo "   kubectl apply -f - <<EOF"
echo "   apiVersion: velero.io/v1"
echo "   kind: Backup"
echo "   metadata:"
echo "     name: manual-backup-\$(date +%Y%m%d-%H%M%S)"
echo "     namespace: dataprotection-microsoft"
echo "   spec:"
echo "     includedNamespaces: [\"default\"]"
echo "     storageLocation: default"
echo "     ttl: 168h0m0s"
echo "   EOF"
echo ""
echo "   # Ver logs de troubleshooting"
echo "   kubectl logs -n dataprotection-microsoft -l app.kubernetes.io/name=velero"

echo ""
echo "📚 Documentación:"
echo "   - docs/azure-native-backup-guide.md"
echo "   - docs/azure-native-backup-troubleshooting.md"
