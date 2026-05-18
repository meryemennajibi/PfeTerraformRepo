#Groupe admin AKS
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

resource "azurerm_role_assignment" "aks_admin_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azuread_group.aks_admin.object_id
}

resource "azurerm_role_assignment" "firewall_admin_policy" {
  scope                = azurerm_firewall_policy.fw_policy.id
  role_definition_name = "Network Contributor"
  principal_id         = azuread_group.firewall_admin.object_id
}

resource "azurerm_role_assignment" "admin_keyvault_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = "5dee7852-9587-42c6-a7f5-d10691e1ff6c"
}

