#!/bin/bash

set -e

TOOL=${1:-terraform}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$(dirname "$SCRIPT_DIR")/environments/dev"

echo "🚀 Desplegando AKS con configuración dinámica y mínimo costo"

# Verificar herramienta
if ! command -v "$TOOL" &> /dev/null; then
    echo "❌ $TOOL no encontrado. Instala con: ./scripts/prerequisites.sh"
    exit 1
fi

# Verificar Azure CLI
if ! az account show &> /dev/null; then
    echo "❌ No autenticado en Azure. Ejecuta: az login"
    exit 1
fi

cd "$ENV_DIR"

echo "📁 Directorio: $ENV_DIR"
echo "🔧 Herramienta: $TOOL"

# Mostrar configuración dinámica actual
current_hour=$(date +%H)
if [[ $current_hour -lt 9 || $current_hour -gt 18 ]]; then
    echo "🌙 Horario detectado: Off-hours ($current_hour:00)"
    echo "💰 Configuración dinámica: 1 nodo Standard_B1s (~$15-20/mes)"
else
    echo "🌞 Horario detectado: Business hours ($current_hour:00)"
    echo "💰 Configuración dinámica: 1 nodo Standard_B2s (~$25-35/mes)"
fi

# Desplegar
echo "🔧 Inicializando..."
$TOOL init

echo "📋 Planificando..."
$TOOL plan

echo "🚀 Desplegando..."
$TOOL apply -auto-approve

# Configurar kubectl
echo "⚙️  Configurando kubectl..."
CLUSTER_NAME=$($TOOL output -raw cluster_info | jq -r '.name')
RESOURCE_GROUP=$($TOOL output -raw cluster_info | jq -r '.resource_group')

az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing

echo ""
echo "✅ Despliegue completado!"
echo "🎯 Cluster: $CLUSTER_NAME"
echo "📦 Grupo: $RESOURCE_GROUP"
echo ""
echo "Verificar:"
echo "kubectl get nodes"
