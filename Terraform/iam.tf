# AKS admin role
resource "azurerm_role_assignment" "aks_admin_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.aks_admin_group_object_id
}

# Firewall admin role
resource "azurerm_role_assignment" "firewall_admin_policy" {
  scope                = azurerm_firewall_policy.fw_policy.id
  role_definition_name = "Network Contributor"
  principal_id         = var.firewall_admin_group_object_id
}

# Security Analyst role on Sentinel / Log Analytics
resource "azurerm_role_assignment" "security_analyst_law" {
  scope                = azurerm_log_analytics_workspace.law.id
  role_definition_name = "Microsoft Sentinel Reader"
  principal_id         = var.security_analyst_group_object_id
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