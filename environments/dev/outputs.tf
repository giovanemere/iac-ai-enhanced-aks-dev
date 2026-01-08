output "cluster_info" {
  description = "Información del cluster"
  value = {
    name           = module.aks.cluster_name
    resource_group = module.aks.resource_group_name
    dynamic_config = module.aks.dynamic_config
  }
}
