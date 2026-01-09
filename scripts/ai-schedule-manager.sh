#!/bin/bash

# Script de integración para gestión de horarios AKS
# Integra con AI Orchestrator para automatización completa

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

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
    echo -e "${PURPLE}🤖 [AI-SCHEDULE]${NC} $1"
}

# Función para detener servicios
ai_stop_services() {
    log_ai "Iniciando secuencia de parada de servicios..."
    
    # Verificar si Python está disponible
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 requerido para AI Schedule Manager"
        return 1
    fi
    
    # Instalar dependencias si es necesario
    pip3 install schedule > /dev/null 2>&1 || true
    
    # Ejecutar agente IA
    python3 "$PROJECT_ROOT/ai-agents/schedule-manager/aks_schedule_manager.py" stop
    
    if [ $? -eq 0 ]; then
        log_success "Servicios detenidos exitosamente"
        log_info "Reinicio automático programado para las 2:45 PM"
    else
        log_error "Error deteniendo servicios"
        return 1
    fi
}

# Función para iniciar servicios
ai_start_services() {
    log_ai "Iniciando secuencia de arranque de servicios..."
    
    python3 "$PROJECT_ROOT/ai-agents/schedule-manager/aks_schedule_manager.py" start
    
    if [ $? -eq 0 ]; then
        log_success "Servicios iniciados exitosamente"
    else
        log_error "Error iniciando servicios"
        return 1
    fi
}

# Función para configurar scheduler automático
ai_setup_scheduler() {
    log_ai "Configurando scheduler automático..."
    
    # Crear servicio systemd para el scheduler
    cat > /tmp/aks-scheduler.service << EOF
[Unit]
Description=AKS AI Schedule Manager
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_ROOT
ExecStart=/usr/bin/python3 $PROJECT_ROOT/ai-agents/schedule-manager/aks_schedule_manager.py schedule
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    log_info "Servicio systemd creado en /tmp/aks-scheduler.service"
    log_info "Para instalar: sudo cp /tmp/aks-scheduler.service /etc/systemd/system/"
    log_info "Para habilitar: sudo systemctl enable aks-scheduler.service"
    log_info "Para iniciar: sudo systemctl start aks-scheduler.service"
}

# Función para verificar estado
ai_check_status() {
    log_ai "Verificando estado de servicios..."
    
    python3 "$PROJECT_ROOT/ai-agents/schedule-manager/aks_schedule_manager.py" status
    
    echo ""
    log_info "Estado de deployments:"
    kubectl get deployments -n default -o wide 2>/dev/null || log_warning "No se pudo acceder al cluster"
    
    echo ""
    log_info "Estado de nodos:"
    kubectl get nodes 2>/dev/null || log_warning "No se pudo acceder al cluster"
}

# Función para configurar horario personalizado
ai_configure_schedule() {
    local stop_time=${1:-"14:45"}
    local start_time=${2:-"08:00"}
    
    log_ai "Configurando horario personalizado..."
    log_info "Hora de parada: $stop_time"
    log_info "Hora de inicio: $start_time"
    
    # Crear configuración personalizada
    cat > "$PROJECT_ROOT/ai-agents/schedule-manager/schedule_config.json" << EOF
{
    "stop_time": "$stop_time",
    "start_time": "$start_time",
    "timezone": "America/Bogota",
    "backup_before_stop": true,
    "scale_node_pools": false,
    "notification_enabled": true
}
EOF

    log_success "Configuración guardada en schedule_config.json"
}

# Función principal
main() {
    echo "🤖 AI Schedule Manager para AKS"
    echo "==============================="
    
    case "${1:-help}" in
        "stop")
            ai_stop_services
            ;;
        "start")
            ai_start_services
            ;;
        "schedule")
            ai_setup_scheduler
            ;;
        "status")
            ai_check_status
            ;;
        "configure")
            ai_configure_schedule "$2" "$3"
            ;;
        "help"|*)
            echo ""
            echo "Uso: $0 <comando> [opciones]"
            echo ""
            echo "Comandos:"
            echo "  stop              - Detener servicios inmediatamente"
            echo "  start             - Iniciar servicios inmediatamente"
            echo "  schedule          - Configurar scheduler automático"
            echo "  status            - Ver estado actual de servicios"
            echo "  configure [stop] [start] - Configurar horarios personalizados"
            echo "  help              - Mostrar esta ayuda"
            echo ""
            echo "Ejemplos:"
            echo "  $0 stop                    # Detener servicios ahora"
            echo "  $0 start                   # Iniciar servicios ahora"
            echo "  $0 configure 14:45 08:00   # Parar a 2:45 PM, iniciar a 8:00 AM"
            echo "  $0 schedule                # Configurar scheduler automático"
            echo ""
            echo "Horario por defecto:"
            echo "  🛑 Parada: 14:45 (2:45 PM)"
            echo "  🚀 Inicio: 08:00 (8:00 AM)"
            ;;
    esac
}

main "$@"
