#!/bin/bash

set -e

echo "🔧 Instalando prerrequisitos para Azure AKS IaC"

# Detectar OS
OS="$(uname -s)"
ARCH="$(uname -m)"

# Función para instalar Azure CLI
install_azure_cli() {
    echo "📦 Instalando Azure CLI..."
    if command -v az &> /dev/null; then
        echo "✅ Azure CLI ya está instalado"
        return
    fi
    
    case $OS in
        Linux*)
            curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
            ;;
        Darwin*)
            brew install azure-cli
            ;;
        *)
            echo "❌ OS no soportado: $OS"
            exit 1
            ;;
    esac
}

# Función para instalar Terraform/OpenTofu
install_terraform() {
    echo "📦 Instalando Terraform y OpenTofu..."
    
    # Terraform
    if ! command -v terraform &> /dev/null; then
        echo "   Instalando Terraform..."
        TERRAFORM_VERSION="1.6.6"
        case $OS in
            Linux*)
                wget "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
                unzip "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
                sudo mv terraform /usr/local/bin/
                rm "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
                ;;
            Darwin*)
                brew install terraform
                ;;
        esac
    else
        echo "✅ Terraform ya está instalado"
    fi
    
    # OpenTofu
    if ! command -v tofu &> /dev/null; then
        echo "   Instalando OpenTofu..."
        case $OS in
            Linux*)
                curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
                chmod +x install-opentofu.sh
                ./install-opentofu.sh --install-method standalone
                rm install-opentofu.sh
                ;;
            Darwin*)
                brew install opentofu
                ;;
        esac
    else
        echo "✅ OpenTofu ya está instalado"
    fi
}

# Función para instalar Terragrunt
install_terragrunt() {
    echo "📦 Instalando Terragrunt..."
    if command -v terragrunt &> /dev/null; then
        echo "✅ Terragrunt ya está instalado"
        return
    fi
    
    case $OS in
        Linux*)
            TERRAGRUNT_VERSION="0.54.8"
            wget "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64"
            chmod +x terragrunt_linux_amd64
            sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt
            ;;
        Darwin*)
            brew install terragrunt
            ;;
    esac
}
install_kubectl() {
    echo "📦 Instalando kubectl..."
    if command -v kubectl &> /dev/null; then
        echo "✅ kubectl ya está instalado"
        return
    fi
    
    case $OS in
        Linux*)
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
            ;;
        Darwin*)
            brew install kubectl
            ;;
        *)
            echo "❌ OS no soportado: $OS"
            exit 1
            ;;
    esac
}

# Verificar herramientas
verify_tools() {
    echo "🔍 Verificando instalaciones..."
    
    if command -v az &> /dev/null; then
        echo "✅ Azure CLI: $(az version --query '"azure-cli"' -o tsv)"
    else
        echo "❌ Azure CLI no encontrado"
        exit 1
    fi
    
    if command -v terraform &> /dev/null; then
        echo "✅ Terraform: $(terraform version -json | jq -r '.terraform_version')"
    else
        echo "❌ Terraform no encontrado"
        exit 1
    fi
    
    if command -v kubectl &> /dev/null; then
        echo "✅ kubectl: $(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"
    else
        echo "❌ kubectl no encontrado"
        exit 1
    fi
}

# Ejecutar instalaciones
install_azure_cli
install_terraform
install_terragrunt
install_kubectl
verify_tools

echo ""
echo "🎉 Prerrequisitos instalados correctamente!"
echo ""
echo "Próximos pasos:"
echo "1. Autenticarse en Azure: az login"
echo "2. Configurar suscripción: az account set --subscription '617fad55-504d-42d2-ba0e-267e8472a399'"
echo "3. Ejecutar despliegue: ./scripts/deploy.sh dev"
