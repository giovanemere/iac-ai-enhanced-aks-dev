terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Módulo AKS con configuración dinámica
module "aks" {
  source = "../../modules/aks"

  project_name = var.project_name
  location     = var.location
  
  # Variables dinámicas se calculan automáticamente en el módulo
}
