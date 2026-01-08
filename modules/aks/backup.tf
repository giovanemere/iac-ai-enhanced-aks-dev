# Azure Backup para AKS - Configuración básica
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

# Output para referencia
output "backup_vault_id" {
  description = "ID del Backup Vault"
  value       = azurerm_data_protection_backup_vault.aks_backup.id
}
