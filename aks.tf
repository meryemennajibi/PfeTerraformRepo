data "azuread_group" "aks_admins" {
  display_name     = var.ad_group_name
  security_enabled = true
}

# 2. Création du Workspace 
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-aks-project"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  depends_on = [azurerm_resource_group.rg]
} 

##########

resource "azurerm_kubernetes_cluster" "aks" {
  # Informations de base
  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "siso-aks"

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Activation d'Azure Policy

  azure_policy_enabled = true

  # --- AJOUT : Container Insights (Config Image) ---
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }

  # Activation du Secrets Store CSI Driver pour Key Vault ---
  key_vault_secrets_provider {
    secret_rotation_enabled = true # Permet de mettre à jour les secrets automatiquement
  }

  # Bloc RBAC 
  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    
    admin_group_object_ids = [data.azuread_group.aks_admins.object_id]
  }

  # Configuration des Nodes (VMs)
  default_node_pool {
    name                = "systempool"
    node_count          = 2
    vm_size             = "Standard_D2ads_v6"
    vnet_subnet_id      = azurerm_subnet.aks_subnet.id
    enable_auto_scaling = false
  }

  # Configuration Réseau 
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
    load_balancer_sku   = "standard"

    service_cidr       = "10.1.0.0/16"   # Plage interne pour les services (différente du VNet)
    dns_service_ip     = "10.1.0.10"    # IP du DNS interne (doit être dans le service_cidr)
  }

  # Ajout indispensable pour que le cluster fonctionne
  identity {
    type = "SystemAssigned"
  }

  depends_on = [
    azurerm_resource_group.rg,
    azurerm_log_analytics_workspace.law
  ]

} 



# Donne à AKS la permission de gérer le réseau dans le subnet
resource "azurerm_role_assignment" "aks_network_contributor" {
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  role_definition_name = "Network Contributor"
  scope                = azurerm_subnet.aks_subnet.id
}