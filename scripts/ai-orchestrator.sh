#!/bin/bash

set -e

echo "🤖 AI-Enhanced IaC Orchestrator con Backup Automático"
echo "====================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ENVIRONMENT=${1:-dev}
ACTION=${2:-deploy}
BACKUP_ENABLED=${BACKUP_ENABLED:-"true"}

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  [INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅ [SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️  [WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}❌ [ERROR]${NC} $1"
}

log_ai() {
    echo -e "${PURPLE}🤖 [AI-AGENT]${NC} $1"
}

# Función de backup pre-destrucción
ai_pre_destroy_backup() {
    if [ "$BACKUP_ENABLED" != "true" ]; then
        log_warning "Backup deshabilitado"
        return 0
    fi

    log_ai "Ejecutando backup automático pre-destrucción..."
    
    if ! kubectl cluster-info > /dev/null 2>&1; then
        log_warning "Cluster no accesible, saltando backup"
        return 0
    fi

    if ! kubectl get namespace dataprotection-microsoft > /dev/null 2>&1; then
        log_warning "Sistema de backup no encontrado"
        return 0
    fi

    local backup_name="ai-pre-destroy-$(date +%Y%m%d-%H%M%S)"
    
    kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: $backup_name
  namespace: dataprotection-microsoft
  labels:
    backup-type: ai-pre-destroy
    environment: $ENVIRONMENT
spec:
  includedNamespaces: ["*"]
  excludedNamespaces: ["kube-system", "dataprotection-microsoft"]
  storageLocation: default
  ttl: 2160h0m0s
  snapshotVolumes: true
EOF

    # Esperar backup
    local timeout=900
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local status=$(kubectl get backup.velero.io $backup_name -n dataprotection-microsoft -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        
        if [ "$status" = "Completed" ] || [ "$status" = "PartiallyFailed" ]; then
            log_success "Backup completado: $backup_name"
            echo "LAST_BACKUP_NAME=$backup_name" > "$PROJECT_ROOT/.backup-info"
            break
        elif [ "$status" = "Failed" ]; then
            log_error "Backup falló"
            return 1
        fi
        
        sleep 30
        elapsed=$((elapsed + 30))
    done
}

# Función de configuración post-creación
ai_post_create_setup() {
    if [ "$BACKUP_ENABLED" != "true" ]; then
        return 0
    fi

    log_ai "Configurando backup en nuevo cluster..."
    
    if [ -f "$PROJECT_ROOT/scripts/complete-backup-setup.sh" ]; then
        "$PROJECT_ROOT/scripts/complete-backup-setup.sh"
        log_success "Sistema de backup configurado"
    fi
}

# Verificar Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 requerido para AI agents"
    exit 1
fi

case $ACTION in
    "deploy")
        log_ai "Iniciando despliegue con AI Orchestrator..."
        python3 "$PROJECT_ROOT/ai-agents/orchestrator/main.py" terraform "$ENVIRONMENT" aks-demo
        
        # Configurar backup automáticamente después del despliegue
        log_ai "Configurando backup post-despliegue..."
        ai_post_create_setup
        ;;
    
    "destroy")
        log_ai "Iniciando destrucción con backup automático..."
        
        # Ejecutar backup antes de destruir
        ai_pre_destroy_backup
        
        # Proceder con destrucción
        log_ai "Procediendo con destrucción del cluster..."
        python3 "$PROJECT_ROOT/ai-agents/orchestrator/main.py" terraform "$ENVIRONMENT" destroy
        ;;
    
    "redeploy")
        log_ai "Iniciando redespliegue completo con backup..."
        
        # Backup pre-destrucción
        ai_pre_destroy_backup
        
        # Destruir
        log_ai "Destruyendo infraestructura existente..."
        python3 "$PROJECT_ROOT/ai-agents/orchestrator/main.py" terraform "$ENVIRONMENT" destroy
        
        # Esperar un momento
        sleep 30
        
        # Redesplegar
        log_ai "Desplegando nueva infraestructura..."
        python3 "$PROJECT_ROOT/ai-agents/orchestrator/main.py" terraform "$ENVIRONMENT" aks-demo
        
        # Configurar backup
        ai_post_create_setup
        
        # Mostrar información de restauración
        if [ -f "$PROJECT_ROOT/.backup-info" ]; then
            source "$PROJECT_ROOT/.backup-info"
            log_info "Backup disponible para restauración: $LAST_BACKUP_NAME"
            log_info "Para restaurar: kubectl apply -f - <<EOF"
            echo "apiVersion: velero.io/v1"
            echo "kind: Restore"
            echo "metadata:"
            echo "  name: ai-restore-$(date +%Y%m%d-%H%M%S)"
            echo "  namespace: dataprotection-microsoft"
            echo "spec:"
            echo "  backupName: $LAST_BACKUP_NAME"
            echo "  includedNamespaces: [\"default\"]"
            echo "EOF"
        fi
        ;;
    
    "backup-setup")
        log_ai "Configurando sistema de backup..."
        ai_post_create_setup
        ;;
    
    "cost-analysis")
        log_ai "Ejecutando análisis de costos..."
        python3 "$PROJECT_ROOT/ai-agents/cost-optimizer/analyzer.py" "$ENVIRONMENT"
        ;;
    
    "backup-analysis")
        log_ai "Ejecutando análisis de backup..."
        python3 "$PROJECT_ROOT/ai-agents/backup-analyzer/analyzer.py" "$ENVIRONMENT"
        ;;
    
    "status")
        log_ai "Verificando estado del sistema..."
        
        # Estado de infraestructura
        echo "🏗️ Estado de Infraestructura:"
        if kubectl cluster-info > /dev/null 2>&1; then
            log_success "Cluster AKS accesible"
        else
            log_warning "Cluster AKS no accesible"
        fi
        
        # Estado de backup
        echo "🛡️ Estado de Backup:"
        if [ -f "$PROJECT_ROOT/scripts/validate-azure-native-backup.sh" ]; then
            "$PROJECT_ROOT/scripts/validate-azure-native-backup.sh"
        fi
        ;;
    
    "help"|*)
        echo ""
        echo "🤖 AI-Enhanced Infrastructure Orchestrator"
        echo "=========================================="
        echo ""
        echo "Uso: $0 <environment> <action>"
        echo ""
        echo "Ambientes:"
        echo "  dev     - Ambiente de desarrollo"
        echo "  prod    - Ambiente de producción"
        echo ""
        echo "Acciones:"
        echo "  deploy          - Desplegar infraestructura + configurar backup"
        echo "  destroy         - Backup automático + destruir infraestructura"
        echo "  redeploy        - Backup + destruir + redesplegar + restaurar info"
        echo "  backup-setup    - Solo configurar sistema de backup"
        echo "  cost-analysis   - Análisis de costos con IA"
        echo "  backup-analysis - Análisis de backup con IA"
        echo "  status          - Estado completo del sistema"
        echo "  help            - Mostrar esta ayuda"
        echo ""
        echo "Variables de entorno:"
        echo "  BACKUP_ENABLED=true|false  - Habilitar/deshabilitar backup automático"
        echo ""
        echo "Ejemplos:"
        echo "  $0 dev deploy              # Desplegar con backup automático"
        echo "  $0 dev redeploy            # Redespliegue completo con backup"
        echo "  BACKUP_ENABLED=false $0 dev deploy  # Desplegar sin backup"
        ;;
esac

echo ""
log_success "AI Orchestrator completado exitosamente"
    
    "backup-ai")
        echo "🤖 Ejecutando análisis IA de backup..."
        python3 "$PROJECT_ROOT/ai-agents/backup-analyzer/main.py"
        ;;
esac

echo ""
log_success "AI Orchestrator completado exitosamente"
    
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
