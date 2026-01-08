variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Región de Azure"
  type        = string
  default     = "East US"
}

# Variables dinámicas para optimización de costos
variable "node_count" {
  description = "Número de nodos (dinámico según hora)"
  type        = number
  default     = null
}

variable "vm_size" {
  description = "Tamaño de VM (dinámico según carga)"
  type        = string
  default     = null
}
