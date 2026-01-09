# 🛡️ Backup AKS - Referencia Rápida

## 🎉 ESTADO ACTUAL: 100% FUNCIONAL

**Portal Azure Backup ACTIVO**: https://portal.azure.com/#@edtech.com.co/resource/subscriptions/617fad55-504d-42d2-ba0e-267e8472a399/resourceGroups/rg-aks-demo-dev/providers/Microsoft.ContainerService/managedclusters/aks-aks-demo-dev/backup

## 🚀 Configuración Completa
```bash
./scripts/complete-backup-setup.sh
```

## 🔍 Validación y Métricas
```bash
# Validación completa
./scripts/validate-azure-native-backup.sh

# Métricas detalladas
./scripts/backup-metrics.sh

# Verificar portal activo
./scripts/retry-backup-instance.sh
```

## ✅ Estado Verificado
```
🛡️ Sistema de Backup: 100% FUNCIONAL
├── Backup Instance: aks-aks-demo-dev-aks-aks-demo-dev-c7410051-a6a5-4c36-a197-f0a791d33071 ✅
├── Backups Velero: 5 completados ✅
├── Portal Azure: ACTIVO ✅
├── Schedules: 1 habilitado ✅
└── Success Rate: 100% ✅
```

## ⏰ Tiempos Reales de Propagación
- **Permisos MSI**: 30-40 minutos (no 5-10 como inicialmente documentado)
- **Backup Instance**: Se crea automáticamente durante propagación
- **Portal activation**: Inmediato una vez propagados los permisos

## 🔍 Verificar Backup Específico

### Desde Portal Azure
```bash
# 1. Obtener Job ID del portal (desde URL)
JOB_ID="f6ac73bd-ba52-427a-a7c1-d1c1e09f5063"

# 2. Verificar job en Azure
az dataprotection job show \
  --resource-group rg-aks-demo-dev \
  --vault-name bv-aks-aks-demo-dev \
  --job-id "$JOB_ID"

# 3. Encontrar backup en cluster
kubectl get backup.velero.io -n dataprotection-microsoft --sort-by=.metadata.creationTimestamp | tail -5

# 4. Verificar detalles
LATEST_BACKUP=$(kubectl get backup.velero.io -n dataprotection-microsoft --sort-by=.metadata.creationTimestamp --no-headers | tail -1 | awk '{print $1}')
kubectl describe backup.velero.io "$LATEST_BACKUP" -n dataprotection-microsoft
```

### Script Automatizado
```bash
./scripts/check-specific-backup.sh [JOB_ID]
```

### Ejemplo Real Verificado
```
✅ Backup Portal → Cluster:
├── Job ID: f6ac73bd-ba52-427a-a7c1-d1c1e09f5063
├── Velero: bkp.6e8b0280-cac0-48d6-a320-2a4b32699026.202601091312082941544
├── Estado: Completed
├── Items: 284/284 (100%)
├── Snapshots: 1/1
└── Duración: 19s
```

## 💰 Costos
- **Estimado**: $5-15/mes
- **Componentes**: Storage Account + Backup Storage + Volume Snapshots
