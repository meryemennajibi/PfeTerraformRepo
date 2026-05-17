variable "resource_group_name" {
  default = "rg-aks-siso"
}

variable "location" {
  description = "La région Azure pour le déploiement"
  default     = "centralus"
}
variable "aks_cluster_name" {
  default = "aks-cluster"
}

variable "aks_admin_group_object_id" {
  type        = string
  description = "Object ID du groupe Entra ID aks-admins"
}

variable "kali_admin_paswd" {
  description = "Admin password for Kali VM"
  type        = string
  sensitive   = true
}
