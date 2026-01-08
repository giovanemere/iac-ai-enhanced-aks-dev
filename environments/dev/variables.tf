variable "subscription_id" {
  description = "ID de la suscripción de Azure"
  type        = string
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "location" {
  description = "Región de Azure"
  type        = string
  default     = "East US"
}
