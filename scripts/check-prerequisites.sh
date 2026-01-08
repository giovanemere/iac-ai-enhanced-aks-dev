#!/bin/bash

set -e

echo "🔍 Verificando prerrequisitos para Azure AKS IaC"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_command() {
    local cmd=$1
    local name=$2
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✅ $name está instalado${NC}"
        return 0
    else
        echo -e "${RED}❌ $name no está instalado${NC}"
        return 1
    fi
}

check_azure_auth() {
    if az account show &> /dev/null; then
        local subscription=$(az account show --query name -o tsv)
        echo -e "${GREEN}✅ Autenticado en Azure (Suscripción: $subscription)${NC}"
        return 0
    else
        echo -e "${RED}❌ No autenticado en Azure${NC}"
        return 1
    fi
}

# Verificar herramientas
echo "🔧 Verificando herramientas..."
check_command "az" "Azure CLI" || MISSING_TOOLS=1
check_command "terraform" "Terraform" || MISSING_TOOLS=1
check_command "tofu" "OpenTofu" || echo "⚠️  OpenTofu no instalado (opcional)"
check_command "terragrunt" "Terragrunt" || echo "⚠️  Terragrunt no instalado (opcional)"
check_command "kubectl" "kubectl" || MISSING_TOOLS=1

# Verificar autenticación
echo ""
echo "🔐 Verificando autenticación..."
check_azure_auth || MISSING_AUTH=1

# Mostrar versiones si están instaladas
echo ""
echo "📋 Versiones instaladas:"
if command -v az &> /dev/null; then
    echo "   Azure CLI: $(az version --query '"azure-cli"' -o tsv)"
fi
if command -v terraform &> /dev/null; then
    echo "   Terraform: $(terraform version | head -n1 | cut -d' ' -f2)"
fi
if command -v kubectl &> /dev/null; then
    echo "   kubectl: $(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)"
fi

# Resultado final
echo ""
if [[ $MISSING_TOOLS == 1 ]]; then
    echo -e "${YELLOW}⚠️  Ejecuta ./scripts/prerequisites.sh para instalar herramientas faltantes${NC}"
fi

if [[ $MISSING_AUTH == 1 ]]; then
    echo -e "${YELLOW}⚠️  Ejecuta 'az login' para autenticarte en Azure${NC}"
fi

if [[ $MISSING_TOOLS != 1 && $MISSING_AUTH != 1 ]]; then
    echo -e "${GREEN}🎉 Todos los prerrequisitos están listos!${NC}"
    echo -e "${GREEN}   Puedes ejecutar: ./scripts/deploy.sh dev${NC}"
fi
