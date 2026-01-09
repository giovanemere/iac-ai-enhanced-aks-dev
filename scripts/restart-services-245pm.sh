#!/bin/bash

# Script para reinicio automático a las 2:45 PM
# Se ejecuta como cron job

echo "🚀 Iniciando servicios a las 2:45 PM - $(date)"

# Verificar si existe el archivo de estado
if [ ! -f "/tmp/aks-replicas-state.txt" ]; then
    echo "❌ No se encontró archivo de estado. Usando valores por defecto."
    echo "nginx:3" > /tmp/aks-replicas-state.txt
fi

echo "📂 Restaurando estado de deployments..."

# Leer estado guardado y restaurar réplicas
while IFS=':' read -r deployment replicas; do
    if [ -n "$deployment" ] && [ -n "$replicas" ]; then
        echo "📈 Restaurando $deployment: 0 → $replicas réplicas"
        kubectl scale deployment "$deployment" --replicas="$replicas" -n default
        
        # Esperar que el deployment esté listo
        echo "⏳ Esperando que $deployment esté listo..."
        kubectl rollout status deployment/"$deployment" -n default --timeout=300s
    fi
done < /tmp/aks-replicas-state.txt

echo ""
echo "✅ Verificando estado final..."
kubectl get deployments -n default
kubectl get pods -n default

echo ""
echo "🧹 Limpiando archivos temporales..."
rm -f /tmp/aks-replicas-state.txt
rm -f /tmp/aks-deployments-state.json

echo "🎉 Servicios reiniciados exitosamente a las $(date)"
