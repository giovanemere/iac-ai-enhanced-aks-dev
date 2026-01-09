#!/bin/bash

# Script para reiniciar cluster AKS a las 2:45 PM
# Máximo ahorro de costos

echo "🚀 Reiniciando cluster AKS a las 2:45 PM - $(date)"

# Iniciar cluster AKS
echo "🔄 Iniciando cluster AKS..."
az aks start --resource-group rg-aks-demo-dev --name aks-aks-demo-dev

if [ $? -eq 0 ]; then
    echo "✅ Cluster AKS iniciado exitosamente"
    
    # Esperar que el cluster esté completamente listo
    echo "⏳ Esperando que el cluster esté listo..."
    sleep 120
    
    # Verificar conectividad
    echo "🔍 Verificando conectividad..."
    kubectl cluster-info --request-timeout=30s
    
    if [ $? -eq 0 ]; then
        echo "✅ Cluster accesible"
        
        # Verificar pods del sistema de backup
        echo "🛡️ Verificando sistema de backup..."
        kubectl get pods -n dataprotection-microsoft --no-headers | wc -l
        
        # Restaurar workloads si hay estado guardado
        if [ -f "/tmp/aks-cluster-state.json" ]; then
            echo "📂 Restaurando workloads desde estado guardado..."
            
            # Leer deployments guardados
            DEPLOYMENTS=$(cat /tmp/aks-cluster-state.json | jq -r '.deployments[] | "\(.name):\(.replicas)"')
            
            echo "$DEPLOYMENTS" | while IFS=':' read -r name replicas; do
                if [ -n "$name" ] && [ -n "$replicas" ]; then
                    echo "📈 Restaurando $name: $replicas réplicas"
                    kubectl scale deployment "$name" --replicas="$replicas" -n default
                fi
            done
            
            # Limpiar archivo de estado
            rm -f /tmp/aks-cluster-state.json
        fi
        
        echo "🎉 Cluster reiniciado exitosamente"
    else
        echo "❌ Error: Cluster no accesible después del reinicio"
    fi
else
    echo "❌ Error iniciando cluster AKS"
    
    # Intentar escalar node pools como alternativa
    echo "🔄 Intentando escalar node pools..."
    az aks nodepool scale \
        --resource-group rg-aks-demo-dev \
        --cluster-name aks-aks-demo-dev \
        --name agentpool \
        --node-count 2
    
    echo "✅ Node pools escalados"
fi

echo "📊 Estado final del cluster:"
az aks show --resource-group rg-aks-demo-dev --name aks-aks-demo-dev --query "{name:name,powerState:powerState.code,nodeResourceGroup:nodeResourceGroup}" -o table

echo "🕐 Operación completada a las $(date)"
