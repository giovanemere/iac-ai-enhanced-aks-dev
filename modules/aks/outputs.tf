output "cluster_name" {
  description = "Nombre del cluster AKS"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "resource_group_name" {
  description = "Nombre del grupo de recursos"
  value       = azurerm_resource_group.aks.name
}

output "kube_config" {
  description = "Configuración de kubectl"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

# Outputs dinámicos
output "dynamic_config" {
  description = "Configuración dinámica aplicada"
  value = {
    node_count    = local.dynamic_node_count
    vm_size       = local.dynamic_vm_size
    is_off_hours  = local.is_off_hours
    current_hour  = local.current_hour
    estimated_cost = local.dynamic_vm_size == "Standard_B1s" ? "$15-20/month" : "$25-35/month"
  }
}
