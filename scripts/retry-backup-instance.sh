#!/bin/bash

# Script para verificar y completar activación del portal Azure Backup
# Ejecutar si el portal no está visible después de la configuración inicial

echo "🔄 Verificación y Activación Final del Portal Azure Backup"
echo "========================================================="
echo "Fecha: $(date)"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

show_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Verificar si ya existe backup instance
echo "🔍 Verificando backup instances existentes..."
EXISTING_INSTANCES=$(az dataprotection backup-instance list --resource-group rg-aks-demo-dev --vault-name bv-aks-aks-demo-dev --query "length(@)" 2>/dev/null || echo "0")

if [ "$EXISTING_INSTANCES" -gt 0 ]; then
    show_success "Backup Instance ya existe"
    
    # Mostrar detalles
    echo "📊 Backup Instances encontrados:"
    az dataprotection backup-instance list --resource-group rg-aks-demo-dev --vault-name bv-aks-aks-demo-dev -o table
    
    echo ""
    show_success "Portal Azure Backup debería estar 100% funcional"
    echo "🌐 URL: https://portal.azure.com/#@edtech.com.co/resource/subscriptions/617fad55-504d-42d2-ba0e-267e8472a399/resourceGroups/rg-aks-demo-dev/providers/Microsoft.ContainerService/managedclusters/aks-aks-demo-dev/backup"
    
    # Verificar backups funcionales
    echo ""
    echo "📦 Verificando backups de Velero..."
    if kubectl get backup.velero.io -n dataprotection-microsoft --no-headers 2>/dev/null | wc -l | grep -q "[1-9]"; then
        BACKUP_COUNT=$(kubectl get backup.velero.io -n dataprotection-microsoft --no-headers 2>/dev/null | wc -l)
        show_success "$BACKUP_COUNT backups de Velero encontrados"
        echo "Últimos backups:"
        kubectl get backup.velero.io -n dataprotection-microsoft --sort-by=.metadata.creationTimestamp | tail -3
    else
        show_warning "No se encontraron backups de Velero"
    fi
    
    exit 0
fi

# Si no existe, intentar crear
echo "⚠️  No se encontró backup instance. Intentando crear..."

# Verificar permisos actuales
echo "Verificando permisos MSI..."
VAULT_MSI=$(az dataprotection backup-vault show --resource-group rg-aks-demo-dev --vault-name bv-aks-aks-demo-dev --query "identity.principalId" -o tsv 2>/dev/null)
if [ -n "$VAULT_MSI" ]; then
    PERMISSIONS=$(az role assignment list --assignee $VAULT_MSI --query "length(@)" 2>/dev/null || echo "0")
    echo "Vault MSI permissions: $PERMISSIONS"
else
    show_error "No se pudo obtener Vault MSI"
    exit 1
fi

# Intentar crear backup instance
echo ""
echo "🔄 Intentando crear Backup Instance..."

# Usar template existente o crear nuevo
if [ ! -f "/tmp/backup-instance-template.json" ]; then
    echo "Creando template de backup instance..."
    
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    CLUSTER_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-aks-demo-dev/providers/Microsoft.ContainerService/managedClusters/aks-aks-demo-dev"
    POLICY_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-aks-demo-dev/providers/Microsoft.DataProtection/backupVaults/bv-aks-aks-demo-dev/backupPolicies/aks-backup-policy"
    
    az dataprotection backup-instance initialize-backupconfig --datasource-type "AzureKubernetesService" > /tmp/backup-config.json
    
    az dataprotection backup-instance initialize \
        --datasource-type "AzureKubernetesService" \
        --datasource-id "$CLUSTER_ID" \
        --datasource-location "eastus" \
        --policy-id "$POLICY_ID" \
        --friendly-name "aks-aks-demo-dev-backup" \
        --backup-configuration @/tmp/backup-config.json > /tmp/backup-instance-template.json
fi

# Intentar crear
if az dataprotection backup-instance create \
    --resource-group rg-aks-demo-dev \
    --vault-name bv-aks-aks-demo-dev \
    --backup-instance @/tmp/backup-instance-template.json 2>/dev/null; then
    
    show_success "Backup Instance creado exitosamente!"
    echo "🌐 Portal Azure Backup ahora debería estar activo"
    
else
    ERROR_MSG=$(az dataprotection backup-instance create \
        --resource-group rg-aks-demo-dev \
        --vault-name bv-aks-aks-demo-dev \
        --backup-instance @/tmp/backup-instance-template.json 2>&1 | grep -o "UserError[^\"]*" | head -1)
    
    if [[ "$ERROR_MSG" == *"MultiProtectionNotAllowed"* ]]; then
        show_warning "Backup Instance ya existe pero no era visible"
        show_success "Verificando nuevamente..."
        
        # Verificar otra vez después del intento
        sleep 10
        NEW_COUNT=$(az dataprotection backup-instance list --resource-group rg-aks-demo-dev --vault-name bv-aks-aks-demo-dev --query "length(@)" 2>/dev/null || echo "0")
        if [ "$NEW_COUNT" -gt 0 ]; then
            show_success "Portal Azure Backup ahora está activo"
        fi
    else
        show_error "Error creando Backup Instance: $ERROR_MSG"
        echo "Los permisos MSI pueden necesitar más tiempo (30-40 minutos total)"
        echo "Ejecutar este script nuevamente en 10-15 minutos"
    fi
fi

echo ""
echo "📋 Resumen:"
echo "- Portal URL: https://portal.azure.com/#@edtech.com.co/resource/.../backup"
echo "- Verificar backup instances: az dataprotection backup-instance list --resource-group rg-aks-demo-dev --vault-name bv-aks-aks-demo-dev"
echo "- Verificar backups Velero: kubectl get backup.velero.io -n dataprotection-microsoft"
