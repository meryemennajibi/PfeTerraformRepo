

# Groupe admin AKS
resource "azuread_group" "aks_admin" {
  display_name     = "aks-admin"
  security_enabled = true
}

# Groupe administrateurs Azure Firewall
resource "azuread_group" "firewall_admin" {
  display_name     = "firewall-admin"
  security_enabled = true
}

# Groupe analystes sécurité
resource "azuread_group" "security_analyst" {
  display_name     = "security-analyst"
  security_enabled = true
}

# Group memberships
resource "azuread_group_member" "cloud_admin_aks_admin" {
  group_object_id  = azuread_group.aks_admin.object_id
  member_object_id = var.cloud_admin_object_id
}

resource "azuread_group_member" "cloud_admin_firewall_admin" {
  group_object_id  = azuread_group.firewall_admin.object_id
  member_object_id = var.cloud_admin_object_id
}

resource "azuread_group_member" "security_analyst_member" {
  group_object_id  = azuread_group.security_analyst.object_id
  member_object_id = var.security_analyst_object_id
}

# AKS admin role
resource "azurerm_role_assignment" "aks_admin_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azuread_group.aks_admin.object_id

  depends_on = [
    azuread_group_member.cloud_admin_aks_admin
  ]
}

# Firewall admin role
resource "azurerm_role_assignment" "firewall_admin_policy" {
  scope                = azurerm_firewall_policy.fw_policy.id
  role_definition_name = "Network Contributor"
  principal_id         = azuread_group.firewall_admin.object_id

  depends_on = [
    azuread_group_member.cloud_admin_firewall_admin
  ]
}

# Key Vault access for Cloud Administrator
resource "azurerm_role_assignment" "admin_keyvault_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.cloud_admin_object_id
}

# AKS identity permission on subnet for LoadBalancer creation
resource "azurerm_role_assignment" "aks_network_contributor_subnet" {
  scope                = azurerm_subnet.aks_subnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}