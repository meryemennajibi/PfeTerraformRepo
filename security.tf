# 1. Création du Network Security Group personnalisé
resource "azurerm_network_security_group" "aks_nsg" {
  name                = "nsg-aks-main"
  location            = "East US" # Doit correspondre à la région de votre cluster
  resource_group_name = "rg-aks-siso"

  tags = {
    Project   = "PFE-Cloud-Security"
    ManagedBy = "Terraform"
  }

  depends_on = [azurerm_resource_group.rg]
}

# 2. REGLES ENTRANTES (INBOUND)


# Pour autoriser la communication entre les composants du cluster : Autoriser le trafic interne au VNet
resource "azurerm_network_security_rule" "allow_vnet_inbound" {
  name                        = "AllowVnetInbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_network_security_group.aks_nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks_nsg.name
}

# Indispensable : Autoriser les sondes de santé Azure (Health Probes)
resource "azurerm_network_security_rule" "allow_lb_inbound" {
  name                        = "AllowAzureLoadBalancerInbound"
  priority                    = 210
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.aks_nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks_nsg.name
}

# Bloquer tout le reste en entrée
resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "DenyAllInbound"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.aks_nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks_nsg.name
}





# 3. CONFIGURATION DU MONITORING ( LOGS)
resource "azurerm_monitor_diagnostic_setting" "nsg_security_logs" {
  name                       = "diag-nsg-security-events"
  target_resource_id         = azurerm_network_security_group.aks_nsg.id
  log_analytics_workspace_id = "/subscriptions/42c20bc6-0b17-4863-9dd7-36fb9fb16729/resourceGroups/rg-aks-siso/providers/Microsoft.OperationalInsights/workspaces/law-aks-project"

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}


# 4. ASSOCIATION (Lien avec Subnet existant)
resource "azurerm_subnet_network_security_group_association" "aks_nsg_assoc" {

  subnet_id                 = azurerm_subnet.aks_subnet.id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id

  depends_on = [azurerm_network_security_group.aks_nsg]
}