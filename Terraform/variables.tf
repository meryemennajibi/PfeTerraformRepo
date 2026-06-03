# =========================================================
# Variables générales du projet
# =========================================================

variable "resource_group_name" {
  description = "Nom du groupe de ressources Azure"
  default     = "rg-aks-siso"
}

variable "location" {
  description = "Région Azure utilisée pour le déploiement"
  default     = "centralus"
}

variable "aks_cluster_name" {
  description = "Nom du cluster AKS"
  default     = "aks-cluster"
}


# =========================================================
# Variables liées à l’administration AKS
# =========================================================

variable "aks_admin_group_object_id" {
  type        = string
  description = "Object ID du groupe Entra ID administrateur AKS"
}


# =========================================================
# Variable sensible pour la VM Kali
# =========================================================

variable "kali_admin_paswd" {
  description = "Mot de passe administrateur de la VM Kali"
  type        = string
  sensitive   = true
}


# =========================================================
# Variables liées aux identités et groupes Entra ID
# =========================================================

variable "cloud_admin_object_id" {
  description = "Object ID de l’administrateur cloud"
  type        = string
}

variable "security_analyst_object_id" {
  description = "Object ID de l’analyste sécurité"
  type        = string
}


variable "security_analyst_group_object_id" {
  description = "Object ID du groupe analyste sécurité"
  type        = string
}

variable "firewall_admin_group_object_id" {
  description = "Object ID du groupe Entra ID firewall-admin"
  type        = string
}

variable "security_analyst_group_object_id" {
  description = "Object ID du groupe Entra ID security-analyst"
  type        = string
}