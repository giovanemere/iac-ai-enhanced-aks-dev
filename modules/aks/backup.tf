# Azure Backup para AKS
resource "azurerm_data_protection_backup_vault" "aks_backup" {
  name                = "bv-${local.cluster_name}"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  datastore_type      = "VaultStore"
  redundancy          = "LocallyRedundant"  # Mínimo costo

  identity {
    type = "SystemAssigned"
  }

  tags = merge(local.tags, {
    Purpose = "AKS Backup"
    CostOptimized = "true"
  })
}

# Backup Policy para AKS
resource "azurerm_data_protection_backup_policy_kubernetes_cluster" "aks_policy" {
  name     = "policy-${local.cluster_name}"
  vault_id = azurerm_data_protection_backup_vault.aks_backup.id

  backup_repeating_time_intervals = ["R/2024-01-01T02:00:00+00:00/P1D"]  # Diario a las 2 AM
  
  # Retención optimizada para costo
  default_retention_duration = "P7D"  # 7 días

  retention_rule {
    name     = "Weekly"
    duration = "P4W"  # 4 semanas
    priority = 20
    
    criteria {
      days_of_week          = ["Sunday"]
      scheduled_backup_times = ["2024-01-01T02:00:00Z"]
    }
  }

  retention_rule {
    name     = "Monthly"
    duration = "P3M"  # 3 meses
    priority = 15
    
    criteria {
      days_of_month         = [1]
      scheduled_backup_times = ["2024-01-01T02:00:00Z"]
    }
  }
}

# Habilitar backup en el cluster AKS
resource "azurerm_data_protection_backup_instance_kubernetes_cluster" "aks_backup_instance" {
  name     = "backup-${local.cluster_name}"
  vault_id = azurerm_data_protection_backup_vault.aks_backup.id
  
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  backup_policy_id      = azurerm_data_protection_backup_policy_kubernetes_cluster.aks_policy.id
  
  snapshot_resource_group_name = azurerm_resource_group.aks.name

  backup_datasource_parameters {
    excluded_namespaces              = ["kube-system", "gatekeeper-system"]
    excluded_resource_types          = ["events", "events.events.k8s.io"]
    cluster_scoped_resources_enabled = true
    included_namespaces              = ["default"]
  }
}
