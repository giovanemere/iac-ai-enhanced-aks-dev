terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

# Variables dinámicas basadas en tiempo/costo
locals {
  # Nombres dinámicos
  resource_group_name = "rg-${var.project_name}-${var.environment}"
  cluster_name       = "aks-${var.project_name}-${var.environment}"
  dns_prefix         = "${var.project_name}-${var.environment}"
  
  # Lógica dinámica para mínimo costo
  current_hour = formatdate("HH", timestamp())
  is_off_hours = tonumber(local.current_hour) < 9 || tonumber(local.current_hour) > 18
  
  # Configuración dinámica de recursos (mínimo costo)
  dynamic_node_count = var.node_count != null ? var.node_count : (local.is_off_hours ? 1 : 1)
  dynamic_vm_size    = var.vm_size != null ? var.vm_size : (local.is_off_hours ? "Standard_B1s" : "Standard_B2s")
  
  # Tags dinámicos
  tags = {
    Environment   = var.environment
    Project      = var.project_name
    ClusterName  = local.cluster_name
    CostLevel    = "minimal"
    AutoOptimized = "true"
    CreatedAt    = timestamp()
  }
}

resource "azurerm_resource_group" "aks" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}

# AKS optimizado para mínimo costo
resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = local.dns_prefix
  
  # Free tier para mínimo costo
  sku_tier = "Free"

  default_node_pool {
    name       = "default"
    node_count = local.dynamic_node_count
    vm_size    = local.dynamic_vm_size
    
    # Configuración mínima de costo
    os_disk_size_gb = 30
    os_disk_type    = "Managed"
  }

  identity {
    type = "SystemAssigned"
  }

  # Red básica para reducir costos
  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "basic"
  }

  tags = local.tags
}
