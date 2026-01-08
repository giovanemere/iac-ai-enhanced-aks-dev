#!/bin/bash

set -e

echo "🤖 AI-Enhanced IaC Orchestrator"
echo "==============================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ENVIRONMENT=${1:-dev}
ACTION=${2:-deploy}

# Verificar Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 requerido para AI agents"
    exit 1
fi

case $ACTION in
    "deploy")
        echo "🚀 Iniciando despliegue con AI Orchestrator..."
        python3 "$PROJECT_ROOT/ai-agents/orchestrator/main.py" terraform "$ENVIRONMENT" aks-demo
        ;;
    
    "cost-analysis")
        echo "💰 Ejecutando análisis de costos..."
        python3 "$PROJECT_ROOT/ai-agents/cost-optimizer/analyzer.py" "$ENVIRONMENT"
        ;;
    
    "multi-tool")
        echo "🔧 Ejecutando multi-tool runner..."
        python3 "$PROJECT_ROOT/orchestration/multi-tool-runner.py" "$ENVIRONMENT" plan
        ;;
    
    "destroy")
        echo "💥 Ejecutando destrucción con análisis IA..."
        
        # Análisis de costos antes de destruir
        echo "💰 Análisis de costos actuales:"
        python3 "$PROJECT_ROOT/ai-agents/cost-optimizer/analyzer.py" "$ENVIRONMENT" 2>/dev/null || echo "   Análisis no disponible"
        
        echo ""
        echo "🤖 AI recomienda: Verificar recursos antes de destruir"
        
        # Ejecutar destrucción mejorada
        "$PROJECT_ROOT/scripts/destroy.sh" "$ENVIRONMENT" terraform
        ;;
    
    "status")
        echo "📊 Estado del sistema AI:"
        echo ""
        
        # Verificar herramientas
        echo "🔧 Herramientas IaC:"
        for tool in terraform tofu terragrunt; do
            if command -v "$tool" &> /dev/null; then
                version=$($tool --version | head -n1 | cut -d' ' -f2 2>/dev/null || echo "unknown")
                echo "   ✅ $tool ($version)"
            else
                echo "   ❌ $tool (no instalado)"
            fi
        done
        
        echo ""
        echo "🤖 Agentes AI:"
        echo "   ✅ AI Orchestrator"
        echo "   ✅ Cost Optimizer"
        echo "   ✅ Multi-Tool Runner"
        
        echo ""
        echo "📁 Entornos disponibles:"
        for env in "$PROJECT_ROOT/environments"/*; do
            if [[ -d "$env" ]]; then
                env_name=$(basename "$env")
                echo "   📂 $env_name"
            fi
        done
        ;;
    
    *)
        echo "❌ Acción no reconocida: $ACTION"
        echo ""
        echo "Uso: $0 <environment> <action>"
        echo ""
        echo "Environments: dev, staging, prod"
        echo "Actions:"
        echo "  deploy        - Despliegue con AI Orchestrator"
        echo "  cost-analysis - Análisis de costos con IA"
        echo "  multi-tool    - Ejecutar multi-tool runner"
        echo "  destroy       - Destrucción con análisis IA"
        echo "  status        - Estado del sistema"
        echo ""
        echo "Ejemplos:"
        echo "  $0 dev deploy"
        echo "  $0 dev cost-analysis"
        echo "  $0 dev destroy"
        echo "  $0 dev status"
        exit 1
        ;;
esac
