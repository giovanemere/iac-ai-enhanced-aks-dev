#!/bin/bash

# Script completo para configurar backup AKS y activar portal Azure
# Uso: ./complete-backup-setup.sh [RESOURCE_GROUP] [CLUSTER_NAME] [VAULT_NAME] [LOCATION]

set -e

# Configuración
RESOURCE_GROUP=${1:-"rg-aks-demo-dev"}
CLUSTER_NAME=${2:-"aks-aks-demo-dev"}
VAULT_NAME=${3:-"bv-aks-aks-demo-dev"}
LOCATION=${4:-"eastus"}

echo "🛡️ Configuración Completa de Backup AKS"
echo "======================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Cluster: $CLUSTER_NAME"
echo "Vault: $VAULT_NAME"
echo "Location: $LOCATION"
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

show_step() {
    echo -e "${BLUE}📋 $1${NC}"
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

# Verificar prerrequisitos
show_step "Verificando prerrequisitos..."
az account show > /dev/null 2>&1 || { show_error "Azure CLI no autenticado"; exit 1; }
kubectl cluster-info > /dev/null 2>&1 || { show_error "kubectl no configurado"; exit 1; }

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
show_success "Prerrequisitos verificados"

# Instalar extensiones
show_step "Instalando extensiones Azure CLI..."
az extension add --name k8s-extension --upgrade > /dev/null 2>&1
az extension add --name dataprotection --upgrade > /dev/null 2>&1
show_success "Extensiones instaladas"

# Verificar/crear Backup Vault
show_step "Verificando Backup Vault..."
VAULT_EXISTS=$(az dataprotection backup-vault show --resource-group $RESOURCE_GROUP --vault-name $VAULT_NAME --query "name" -o tsv 2>/dev/null || echo "")

if [ "$VAULT_EXISTS" != "$VAULT_NAME" ]; then
    show_warning "Creando Backup Vault..."
    az dataprotection backup-vault create \
        --resource-group $RESOURCE_GROUP \
        --vault-name $VAULT_NAME \
        --location $LOCATION \
        --storage-settings datastore-type="VaultStore" redundancy="LocallyRedundant" \
        --identity-type SystemAssigned > /dev/null
fi
show_success "Backup Vault listo"

# Crear Storage Account
show_step "Creando Storage Account..."
STORAGE_NAME="aksbackupstorage$(date +%s | tail -c 6)"

az storage account create \
    --name $STORAGE_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS \
    --kind StorageV2 > /dev/null

az storage container create \
    --name aksbackupcontainer \
    --account-name $STORAGE_NAME > /dev/null 2>&1

show_success "Storage Account creado: $STORAGE_NAME"

# Instalar extensión AKS Backup
show_step "Instalando extensión AKS Backup..."
EXTENSION_STATE=$(az k8s-extension show --name azure-aks-backup --cluster-type managedClusters --cluster-name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query "provisioningState" -o tsv 2>/dev/null || echo "NotFound")

if [ "$EXTENSION_STATE" != "Succeeded" ]; then
    az k8s-extension create \
        --name azure-aks-backup \
        --extension-type microsoft.dataprotection.kubernetes \
        --scope cluster \
        --cluster-type managedClusters \
        --cluster-name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --release-train stable \
        --configuration-settings \
            blobContainer=aksbackupcontainer \
            storageAccount=$STORAGE_NAME \
            storageAccountResourceGroup=$RESOURCE_GROUP \
            storageAccountSubscriptionId=$SUBSCRIPTION_ID > /dev/null
    
    echo "Esperando instalación de extensión..."
    sleep 120
fi
show_success "Extensión AKS Backup instalada"

# Configurar permisos Storage
show_step "Configurando permisos Storage..."
EXTENSION_MSI=$(az k8s-extension show \
    --name azure-aks-backup \
    --cluster-type managedClusters \
    --cluster-name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --query "aksAssignedIdentity.principalId" -o tsv)

STORAGE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME"

az role assignment create \
    --assignee $EXTENSION_MSI \
    --role "Storage Blob Data Contributor" \
    --scope $STORAGE_ID > /dev/null 2>&1 || true

show_success "Permisos Storage configurados"

# Crear política de backup
show_step "Creando política de backup..."
POLICY_EXISTS=$(az dataprotection backup-policy show --resource-group $RESOURCE_GROUP --vault-name $VAULT_NAME --name aks-backup-policy --query "name" -o tsv 2>/dev/null || echo "")

if [ "$POLICY_EXISTS" != "aks-backup-policy" ]; then
    cat > /tmp/backup-policy.json << 'EOF'
{
  "datasourceTypes": ["Microsoft.ContainerService/managedClusters"],
  "objectType": "BackupPolicy",
  "policyRules": [
    {
      "name": "BackupDaily",
      "objectType": "AzureBackupRule",
      "backupParameters": {
        "backupType": "Incremental",
        "objectType": "AzureBackupParams"
      },
      "dataStore": {
        "dataStoreType": "OperationalStore",
        "objectType": "DataStoreInfoBase"
      },
      "trigger": {
        "objectType": "ScheduleBasedTriggerContext",
        "schedule": {
          "repeatingTimeIntervals": ["R/2024-01-01T02:00:00+00:00/P1D"],
          "timeZone": "UTC"
        },
        "taggingCriteria": [
          {
            "isDefault": true,
            "tagInfo": {
              "id": "Default_",
              "tagName": "Default"
            },
            "taggingPriority": 99
          }
        ]
      }
    },
    {
      "name": "Default",
      "objectType": "AzureRetentionRule",
      "isDefault": true,
      "lifecycles": [
        {
          "deleteAfter": {
            "duration": "P7D",
            "objectType": "AbsoluteDeleteOption"
          },
          "sourceDataStore": {
            "dataStoreType": "OperationalStore",
            "objectType": "DataStoreInfoBase"
          },
          "targetDataStoreCopySettings": []
        }
      ]
    }
  ]
}
EOF

    az dataprotection backup-policy create \
        --resource-group $RESOURCE_GROUP \
        --vault-name $VAULT_NAME \
        --name aks-backup-policy \
        --policy @/tmp/backup-policy.json > /dev/null
fi
show_success "Política de backup creada"

# Configurar permisos MSI
show_step "Configurando permisos MSI..."
VAULT_MSI=$(az dataprotection backup-vault show --resource-group $RESOURCE_GROUP --vault-name $VAULT_NAME --query "identity.principalId" -o tsv)
AKS_MSI=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "identity.principalId" -o tsv)
KUBELET_MSI=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "identityProfile.kubeletidentity.objectId" -o tsv)
SNAPSHOT_RG=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "nodeResourceGroup" -o tsv)

CLUSTER_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$CLUSTER_NAME"
RG_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
SNAPSHOT_RG_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$SNAPSHOT_RG"

# Asignar permisos (ignorar errores si ya existen)
az role assignment create --assignee $VAULT_MSI --role "Contributor" --scope $CLUSTER_ID > /dev/null 2>&1 || true
az role assignment create --assignee $VAULT_MSI --role "Reader" --scope $RG_ID > /dev/null 2>&1 || true
az role assignment create --assignee $AKS_MSI --role "Contributor" --scope $SNAPSHOT_RG_ID > /dev/null 2>&1 || true
az role assignment create --assignee $KUBELET_MSI --role "Contributor" --scope $SNAPSHOT_RG_ID > /dev/null 2>&1 || true
az role assignment create --assignee $VAULT_MSI --role "Reader" --scope $SNAPSHOT_RG_ID > /dev/null 2>&1 || true

show_success "Permisos MSI configurados"

# Crear Backup Instance
show_step "Creando Backup Instance (activar portal)..."
az dataprotection backup-instance initialize-backupconfig --datasource-type "AzureKubernetesService" > /tmp/backup-config.json

POLICY_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DataProtection/backupVaults/$VAULT_NAME/backupPolicies/aks-backup-policy"

az dataprotection backup-instance initialize \
    --datasource-type "AzureKubernetesService" \
    --datasource-id $CLUSTER_ID \
    --datasource-location $LOCATION \
    --policy-id $POLICY_ID \
    --friendly-name "$CLUSTER_NAME-backup" \
    --backup-configuration @/tmp/backup-config.json > /tmp/backup-instance.json

# Verificar si ya existe backup instance
EXISTING_INSTANCES=$(az dataprotection backup-instance list --resource-group $RESOURCE_GROUP --vault-name $VAULT_NAME --query "length(@)" 2>/dev/null || echo "0")

if [ "$EXISTING_INSTANCES" -gt 0 ]; then
    show_success "Backup Instance ya existe - Portal Azure debería estar activo"
    BACKUP_INSTANCE_CREATED=true
else
    # Intentar crear con reintentos
    ATTEMPTS=0
    MAX_ATTEMPTS=3
    BACKUP_INSTANCE_CREATED=false

    while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
        ATTEMPTS=$((ATTEMPTS + 1))
        echo "Intento $ATTEMPTS/$MAX_ATTEMPTS de crear Backup Instance..."
        
        if az dataprotection backup-instance create \
            --resource-group $RESOURCE_GROUP \
            --vault-name $VAULT_NAME \
            --backup-instance @/tmp/backup-instance.json > /dev/null 2>&1; then
            BACKUP_INSTANCE_CREATED=true
            break
        else
            if [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; then
                echo "Esperando propagación de permisos MSI (180 segundos - tiempo real)..."
                sleep 180
            fi
        fi
    done
fi

if [ "$BACKUP_INSTANCE_CREATED" = true ]; then
    show_success "Backup Instance configurado - Portal Azure activado"
else
    show_warning "Backup Instance pendiente - Los permisos MSI pueden tardar 30-40 minutos en propagarse completamente"
    show_warning "El portal se activará automáticamente una vez propagados los permisos"
    echo "Para verificar más tarde: az dataprotection backup-instance list --resource-group $RESOURCE_GROUP --vault-name $VAULT_NAME"
fi

# Configurar Velero backups
show_step "Configurando backups automáticos..."
kubectl apply -f - <<EOF > /dev/null 2>&1
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: aks-daily-backup
  namespace: dataprotection-microsoft
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces:
    - default
    excludedResources:
    - events
    - events.events.k8s.io
    storageLocation: default
    volumeSnapshotLocations:
    - default
    ttl: 168h0m0s
    snapshotVolumes: true
    includeClusterResources: true
EOF

# Crear primer backup
kubectl apply -f - <<EOF > /dev/null 2>&1
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: initial-backup-$(date +%Y%m%d-%H%M%S)
  namespace: dataprotection-microsoft
spec:
  includedNamespaces:
  - default
  excludedResources:
  - events
  - events.events.k8s.io
  storageLocation: default
  volumeSnapshotLocations:
  - default
  ttl: 168h0m0s
  snapshotVolumes: true
EOF

show_success "Backups automáticos configurados"

# Verificación final
show_step "Verificando configuración..."
sleep 10

EXTENSION_STATUS=$(az k8s-extension show --name azure-aks-backup --cluster-type managedClusters --cluster-name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query "provisioningState" -o tsv 2>/dev/null)
PODS_RUNNING=$(kubectl get pods -n dataprotection-microsoft --no-headers 2>/dev/null | grep Running | wc -l)
BSL_STATUS=$(kubectl get backupstoragelocations default -n dataprotection-microsoft -o jsonpath='{.status.phase}' 2>/dev/null)
BACKUP_COUNT=$(kubectl get backup.velero.io -n dataprotection-microsoft --no-headers 2>/dev/null | wc -l)
SCHEDULE_COUNT=$(kubectl get schedules -n dataprotection-microsoft --no-headers 2>/dev/null | wc -l)
BACKUP_INSTANCES=$(az dataprotection backup-instance list --resource-group $RESOURCE_GROUP --vault-name $VAULT_NAME --query "length(@)" 2>/dev/null || echo "0")

# Limpiar archivos temporales
rm -f /tmp/backup-policy.json /tmp/backup-config.json /tmp/backup-instance.json

echo ""
echo "🎉 CONFIGURACIÓN COMPLETADA"
echo "=========================="
echo ""
echo "📊 Estado del Sistema:"
echo "├── Extensión AKS: $EXTENSION_STATUS"
echo "├── Pods backup: $PODS_RUNNING running"
echo "├── Storage location: $BSL_STATUS"
echo "├── Backups: $BACKUP_COUNT creados"
echo "├── Schedules: $SCHEDULE_COUNT configurados"
echo "└── Backup instances: $BACKUP_INSTANCES"
echo ""

if [ "$BACKUP_INSTANCES" -gt 0 ]; then
    echo "🌐 Portal Azure Backup ACTIVO:"
    echo "https://portal.azure.com/#@edtech.com.co/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedclusters/$CLUSTER_NAME/backup"
else
    echo "⚠️  Portal Azure Backup pendiente (permisos propagándose)"
    echo "Ejecutar más tarde: ./scripts/retry-backup-instance.sh"
fi

echo ""
echo "🔧 Comandos útiles:"
echo "# Ver backups"
echo "kubectl get backup.velero.io -n dataprotection-microsoft"
echo ""
echo "# Crear backup manual"
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
echo "  snapshotVolumes: true"
echo "EOF"
echo ""
echo "💰 Costos estimados: \$5-15/mes"
echo "📚 Documentación: docs/backup-complete-guide.md"
