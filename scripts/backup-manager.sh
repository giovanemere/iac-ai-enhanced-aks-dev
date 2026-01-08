#!/bin/bash

set -e

echo "🔄 AKS Backup Manager - AI Enhanced"
echo "==================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ACTION=${1:-status}
NAMESPACE=${2:-all}

# Función para mostrar sección
show_section() {
    echo ""
    echo "🔹 $1"
    echo "----------------------------------------"
}

# Función para backup de configuraciones
backup_configurations() {
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    echo "📦 Creando backup de configuraciones en: $backup_dir"
    
    # Backup de todos los recursos
    kubectl get all --all-namespaces -o yaml > "$backup_dir/all-resources.yaml"
    
    # Backup por namespace
    for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
        if [[ "$ns" != "kube-"* ]]; then
            echo "   📂 Backup namespace: $ns"
            kubectl get all -n "$ns" -o yaml > "$backup_dir/namespace-$ns.yaml"
        fi
    done
    
    # Backup de ConfigMaps y Secrets
    kubectl get configmaps --all-namespaces -o yaml > "$backup_dir/configmaps.yaml"
    kubectl get secrets --all-namespaces -o yaml > "$backup_dir/secrets.yaml"
    
    # Backup de PVCs
    kubectl get pvc --all-namespaces -o yaml > "$backup_dir/pvcs.yaml"
    
    echo "✅ Backup de configuraciones completado"
    echo "📁 Ubicación: $backup_dir"
}

# Función para crear snapshots de volúmenes
create_volume_snapshots() {
    echo "📸 Creando snapshots de volúmenes persistentes..."
    
    # Obtener PVCs
    local pvcs=$(kubectl get pvc --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}')
    
    if [[ -z "$pvcs" ]]; then
        echo "ℹ️  No hay PVCs para hacer snapshot"
        return
    fi
    
    while read -r namespace pvc_name; do
        if [[ -n "$pvc_name" ]]; then
            echo "   📸 Snapshot PVC: $namespace/$pvc_name"
            
            # Crear VolumeSnapshot
            cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: ${pvc_name}-snapshot-$(date +%Y%m%d-%H%M%S)
  namespace: $namespace
spec:
  volumeSnapshotClassName: csi-azuredisk-vsc
  source:
    persistentVolumeClaimName: $pvc_name
EOF
        fi
    done <<< "$pvcs"
    
    echo "✅ Snapshots de volúmenes creados"
}

# Función para verificar estado de backups
check_backup_status() {
    echo "📊 Estado de backups de Azure:"
    
    # Verificar si existe el backup vault
    local rg_name=$(terraform output -raw resource_group_name 2>/dev/null || echo "rg-aks-demo-dev")
    local cluster_name=$(terraform output -raw cluster_name 2>/dev/null || echo "aks-aks-demo-dev")
    
    if az backup vault list --resource-group "$rg_name" --query "[?contains(name, 'bv-')]" -o table 2>/dev/null; then
        echo "✅ Backup Vault configurado"
        
        # Mostrar políticas de backup
        echo ""
        echo "📋 Políticas de backup:"
        az backup policy list --resource-group "$rg_name" --vault-name "bv-$cluster_name" -o table 2>/dev/null || echo "   No hay políticas configuradas"
        
    else
        echo "⚠️  Backup Vault no configurado"
        echo "💡 Ejecuta: terraform apply para configurar backup nativo"
    fi
    
    echo ""
    echo "📸 Snapshots de volúmenes:"
    kubectl get volumesnapshots --all-namespaces 2>/dev/null || echo "   No hay snapshots disponibles"
}

# Función para restaurar desde backup
restore_from_backup() {
    local backup_file=$1
    
    if [[ ! -f "$backup_file" ]]; then
        echo "❌ Archivo de backup no encontrado: $backup_file"
        return 1
    fi
    
    echo "🔄 Restaurando desde: $backup_file"
    
    # Confirmar restauración
    read -p "⚠️  ¿Confirmas la restauración? Esto puede sobrescribir recursos existentes (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Restauración cancelada"
        return 1
    fi
    
    # Aplicar backup
    kubectl apply -f "$backup_file"
    echo "✅ Restauración completada"
}

# Función principal
case $ACTION in
    "backup")
        show_section "Backup Manual de Configuraciones"
        backup_configurations
        
        show_section "Backup de Volúmenes Persistentes"
        create_volume_snapshots
        ;;
    
    "status")
        show_section "Estado de Backups"
        check_backup_status
        
        show_section "Backups Locales Disponibles"
        if [[ -d "backups" ]]; then
            ls -la backups/ | tail -10
        else
            echo "   No hay backups locales"
        fi
        ;;
    
    "restore")
        if [[ -z "$2" ]]; then
            echo "❌ Especifica el archivo de backup para restaurar"
            echo "Uso: $0 restore <archivo_backup>"
            exit 1
        fi
        
        show_section "Restauración desde Backup"
        restore_from_backup "$2"
        ;;
    
    "schedule")
        show_section "Configurar Backup Automático"
        echo "📅 Configurando backup diario a las 2:00 AM..."
        
        # Crear CronJob para backup automático
        cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: aks-backup-cronjob
  namespace: default
spec:
  schedule: "0 2 * * *"  # Diario a las 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: backup-sa
          containers:
          - name: backup
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              echo "Ejecutando backup automático..."
              kubectl get all --all-namespaces -o yaml > /backup/backup-\$(date +%Y%m%d_%H%M%S).yaml
              echo "Backup completado"
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure
EOF
        
        echo "✅ CronJob de backup configurado"
        ;;
    
    "ai-analysis")
        show_section "Análisis IA de Backup"
        echo "🤖 Analizando estrategia de backup con IA..."
        
        # Análisis de recursos críticos
        echo ""
        echo "📊 Recursos críticos detectados:"
        kubectl get pvc --all-namespaces --no-headers | wc -l | xargs echo "   PVCs:"
        kubectl get deployments --all-namespaces --no-headers | wc -l | xargs echo "   Deployments:"
        kubectl get configmaps --all-namespaces --no-headers | wc -l | xargs echo "   ConfigMaps:"
        
        echo ""
        echo "💰 Estimación de costos de backup:"
        echo "   Backup Vault: ~$5/mes"
        echo "   Snapshots: ~$0.05/GB/mes"
        echo "   Retención 7 días: Costo mínimo"
        
        echo ""
        echo "🎯 Recomendaciones IA:"
        echo "   • Backup diario a las 2 AM (horario off-peak)"
        echo "   • Retención: 7 días diario, 4 semanas semanal"
        echo "   • Excluir namespaces del sistema (kube-system)"
        echo "   • Usar LocallyRedundant para mínimo costo"
        ;;
    
    *)
        echo "❌ Acción no reconocida: $ACTION"
        echo ""
        echo "Uso: $0 <action> [options]"
        echo ""
        echo "Actions:"
        echo "  backup      - Crear backup manual completo"
        echo "  status      - Ver estado de backups"
        echo "  restore     - Restaurar desde backup"
        echo "  schedule    - Configurar backup automático"
        echo "  ai-analysis - Análisis IA de estrategia de backup"
        echo ""
        echo "Ejemplos:"
        echo "  $0 backup"
        echo "  $0 status"
        echo "  $0 restore backups/20240108_140000/all-resources.yaml"
        echo "  $0 ai-analysis"
        exit 1
        ;;
esac

echo ""
echo "🎉 Operación de backup completada!"
