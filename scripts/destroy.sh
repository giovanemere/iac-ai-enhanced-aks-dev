#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
TOOL=${2:-terraform}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$PROJECT_DIR/environments/$ENVIRONMENT"

echo "🤖 AI-Enhanced Destruction - Entorno: $ENVIRONMENT"
echo "=================================================="

# Verificar herramienta
if ! command -v "$TOOL" &> /dev/null; then
    echo "❌ $TOOL no encontrado"
    echo "Herramientas disponibles:"
    for t in terraform tofu terragrunt; do
        if command -v "$t" &> /dev/null; then
            echo "   ✅ $t"
            TOOL="$t"
            break
        fi
    done
fi

cd "$ENV_DIR"
echo "📁 Directorio: $ENV_DIR"
echo "🔧 Herramienta: $TOOL"

# AI Cost Analysis antes de destruir
echo ""
echo "💰 Análisis de costos antes de destruir:"
if [[ -f "$PROJECT_DIR/ai-agents/cost-optimizer/analyzer.py" ]]; then
    python3 "$PROJECT_DIR/ai-agents/cost-optimizer/analyzer.py" "$ENVIRONMENT" 2>/dev/null || echo "   Análisis no disponible"
fi

# Mostrar recursos a destruir
echo ""
echo "📋 Recursos que serán destruidos:"
$TOOL plan -destroy | grep -E "(will be destroyed|Plan:)" || echo "   No se pueden mostrar recursos"

# Confirmar destrucción
echo ""
read -p "¿Confirmas la destrucción de la infraestructura? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Operación cancelada por el usuario"
    exit 1
fi

# Destruir con herramienta seleccionada
echo ""
echo "💥 Destruyendo infraestructura con $TOOL..."

case $TOOL in
    terraform)
        terraform destroy -auto-approve
        ;;
    tofu)
        tofu destroy -auto-approve
        ;;
    terragrunt)
        terragrunt destroy -auto-approve
        ;;
    *)
        echo "❌ Herramienta no soportada: $TOOL"
        exit 1
        ;;
esac

# Limpiar archivos locales
echo ""
echo "🧹 Limpiando archivos locales..."
rm -rf .terraform/
rm -f .terraform.lock.hcl
rm -f terraform.tfstate*
rm -f *.tfplan

echo ""
echo "✅ Infraestructura destruida completamente!"
echo "💰 Costos detenidos - No se generarán más gastos"
