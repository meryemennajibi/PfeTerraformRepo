resource "azurerm_kubernetes_cluster" "aks" {
  # =========================
  # Informations de base
  # =========================
  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "siso-aks"

  # =========================
  # Sécurité et identité
  # =========================
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  azure_policy_enabled      = true

  identity {
    type = "SystemAssigned"
  }

  # =========================
  # Authentification Entra ID + Azure RBAC
  # =========================
  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    admin_group_object_ids = [azuread_group.aks_admin.object_id]
  }

  # =========================
  # Pool de nœuds système
  # =========================
  default_node_pool {
    name                = "systempool"
    node_count          = 2
    vm_size             = "Standard_D2s_v4"
    vnet_subnet_id      = azurerm_subnet.aks_subnet.id
    enable_auto_scaling = false
  }

  # =========================
  # Réseau AKS
  # =========================
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
    load_balancer_sku   = "standard"

    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
  }

  # =========================
  # Supervision Container Insights
  # =========================
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }

  # =========================
  # Intégration Key Vault CSI Driver
  # =========================
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  depends_on = [
    azurerm_resource_group.rg,
    azurerm_log_analytics_workspace.law,
    azuread_group.aks_admin
  ]
}