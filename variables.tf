variable "resource_group_name" {
  default = "rg-aks-siso" 
}

variable "location" {
  description = "La région Azure pour le déploiement"
  default     = "eastus"
}
variable "aks_cluster_name" {
  default = "aks-cluster"
}

variable "ad_group_name" {
  default = "aks-admins" # Le nom exact du groupe Entra ID
}
