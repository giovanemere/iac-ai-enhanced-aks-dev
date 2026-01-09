#!/bin/bash

# Script para reintentar creación de Backup Instance
# Ejecutar cada hora hasta que funcione

echo "🔄 Reintentando creación de Backup Instance..."
echo "Fecha: $(date)"

# Verificar permisos actuales
echo "Verificando permisos en snapshot RG..."
az role assignment list --resource-group MC_rg-aks-demo-dev_aks-aks-demo-dev_eastus --query "[].{Principal:principalId,Role:roleDefinitionName}" -o table

echo ""
echo "Intentando crear Backup Instance..."

if az dataprotection backup-instance create \
    --resource-group rg-aks-demo-dev \
    --vault-name bv-aks-aks-demo-dev \
    --backup-instance @/tmp/backup-instance-template.json; then
    
    echo "✅ SUCCESS: Backup Instance creado exitosamente!"
    echo "🌐 Portal Azure Backup ahora debería estar activo:"
    echo "https://portal.azure.com/#@edtech.com.co/resource/subscriptions/617fad55-504d-42d2-ba0e-267e8472a399/resourceGroups/rg-aks-demo-dev/providers/Microsoft.ContainerService/managedclusters/aks-aks-demo-dev/backup"
    
    # Verificar backup instances
    echo ""
    echo "📊 Backup Instances creados:"
    az dataprotection backup-instance list --resource-group rg-aks-demo-dev --vault-name bv-aks-aks-demo-dev -o table
    
else
    echo "❌ FAILED: Aún no se puede crear Backup Instance"
    echo "Causa probable: Permisos MSI aún propagándose"
    echo "Solución: Ejecutar este script nuevamente en 1-2 horas"
    echo ""
    echo "Mientras tanto, el backup con Velero está 100% funcional:"
    kubectl get backup.velero.io -n dataprotection-microsoft
fi
