#!/bin/bash

set -e

echo "🎯 Demo de Componentes AKS - AI Enhanced"
echo "========================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$PROJECT_ROOT/environments/dev"

# Función para mostrar separador
show_section() {
    echo ""
    echo "🔹 $1"
    echo "----------------------------------------"
}

# 1. Verificar configuración dinámica IA
show_section "Configuración Dinámica IA"
cd "$ENV_DIR"
if terraform output cluster_info &>/dev/null; then
    echo "📊 Configuración IA aplicada:"
    terraform output cluster_info | jq '.dynamic_config' 2>/dev/null || terraform output cluster_info
else
    echo "❌ No se puede obtener configuración IA"
fi

# 2. Verificar conectividad del cluster
show_section "Estado del Cluster"
echo "🔍 Verificando nodos:"
kubectl get nodes -o wide

echo ""
echo "📦 Pods del sistema:"
kubectl get pods -n kube-system --no-headers | wc -l | xargs echo "Total pods sistema:"

# 3. Monitorear recursos
show_section "Monitoreo de Recursos"
echo "💻 Uso de recursos de nodos:"
if kubectl top nodes &>/dev/null; then
    kubectl top nodes
else
    echo "⏳ Metrics server iniciando... (disponible en ~2 minutos)"
fi

# 4. Demo de aplicaciones
show_section "Demo de Aplicaciones"

# Nginx básico
echo "🌐 Desplegando Nginx (si no existe):"
if ! kubectl get deployment nginx &>/dev/null; then
    kubectl create deployment nginx --image=nginx
    echo "✅ Deployment nginx creado"
else
    echo "✅ Deployment nginx ya existe"
fi

# Exponer servicio
echo ""
echo "🔗 Configurando LoadBalancer:"
if ! kubectl get service nginx &>/dev/null; then
    kubectl expose deployment nginx --port=80 --type=LoadBalancer
    echo "✅ Service LoadBalancer creado"
else
    echo "✅ Service LoadBalancer ya existe"
fi

# Esperar IP externa
echo ""
echo "⏳ Esperando IP externa del LoadBalancer..."
for i in {1..30}; do
    EXTERNAL_IP=$(kubectl get service nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [[ -n "$EXTERNAL_IP" && "$EXTERNAL_IP" != "null" ]]; then
        echo "✅ IP externa asignada: $EXTERNAL_IP"
        break
    fi
    echo "   Intento $i/30 - Esperando IP..."
    sleep 10
done

# 5. Probar conectividad
show_section "Pruebas de Conectividad"
if [[ -n "$EXTERNAL_IP" && "$EXTERNAL_IP" != "null" ]]; then
    echo "🌐 Probando aplicación en http://$EXTERNAL_IP"
    if curl -s --connect-timeout 10 "http://$EXTERNAL_IP" | grep -q "Welcome to nginx"; then
        echo "✅ Aplicación respondiendo correctamente"
        echo "🔗 Acceso público: http://$EXTERNAL_IP"
    else
        echo "⏳ Aplicación aún iniciando..."
    fi
else
    echo "⚠️  IP externa no disponible aún"
fi

# 6. Demo de escalado
show_section "Demo de Auto-Scaling"
echo "📈 Escalando aplicación a 3 réplicas:"
kubectl scale deployment nginx --replicas=3

echo ""
echo "⏳ Esperando pods adicionales..."
sleep 15

echo "📦 Estado de réplicas:"
kubectl get pods -l app=nginx -o wide

# 7. Mostrar servicios completos
show_section "Resumen de Servicios"
echo "🔧 Todos los servicios:"
kubectl get services

echo ""
echo "📱 Deployments activos:"
kubectl get deployments

# 8. Información de costos
show_section "Información de Costos"
echo "💰 Análisis de costos actual:"
python3 "$PROJECT_ROOT/ai-agents/cost-optimizer/analyzer.py" dev 2>/dev/null || echo "Análisis no disponible"

# 9. Comandos útiles
show_section "Comandos Útiles para Continuar"
echo "📋 Comandos de monitoreo:"
echo "   kubectl get all"
echo "   kubectl top nodes"
echo "   kubectl top pods"
echo ""
echo "🔧 Comandos de gestión:"
echo "   kubectl scale deployment nginx --replicas=5"
echo "   kubectl delete deployment nginx"
echo "   kubectl delete service nginx"
echo ""
echo "💰 Análisis de costos:"
echo "   ./scripts/ai-orchestrator.sh dev cost-analysis"
echo ""
echo "🗑️  Destruir infraestructura:"
echo "   ./scripts/ai-orchestrator.sh dev destroy"

echo ""
echo "🎉 Demo completado exitosamente!"
echo "🌐 Aplicación disponible en: http://$EXTERNAL_IP"
echo "💰 Costo estimado: $43-53/mes (incluye LoadBalancer)"
