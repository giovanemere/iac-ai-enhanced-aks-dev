#!/bin/bash

# Script para crear restore desde backup
# Uso: ./create-restore.sh <BACKUP_NAME> [NAMESPACE]

BACKUP_NAME=${1:-"aks-config-backup-20260109-072145"}
TARGET_NAMESPACE=${2:-"default"}

echo "🔄 Creando restore desde backup: $BACKUP_NAME"
echo "Namespace destino: $TARGET_NAMESPACE"

kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: restore-$(date +%Y%m%d-%H%M%S)
  namespace: dataprotection-microsoft
spec:
  backupName: $BACKUP_NAME
  includedNamespaces:
  - $TARGET_NAMESPACE
  restorePVs: true
  preserveNodePorts: false
EOF

echo "✅ Restore creado exitosamente"
echo "Verificar con: kubectl get restore -n dataprotection-microsoft"
