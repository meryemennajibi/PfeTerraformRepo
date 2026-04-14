# 1. IP Publique Standard
resource "azurerm_public_ip" "fw_pip" {
  name                = "pip-azure-firewall"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on          = [azurerm_resource_group.rg]
}

# 2. DEUXIÈME IP Publique (Management) - Obligatoire pour le SKU Basic
resource "azurerm_public_ip" "fw_mgmt_pip" {
  name                = "pip-fw-management"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on          = [azurerm_resource_group.rg]
}

# 3. L'instance Azure Firewall 
resource "azurerm_firewall" "fw" {
  name                = "fw-projet-siso"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"
  firewall_policy_id  = azurerm_firewall_policy.fw_policy.id

  # Configuration Trafic Client
  ip_configuration {
    name                 = "fw-config"
    subnet_id            = azurerm_subnet.fw_subnet.id
    public_ip_address_id = azurerm_public_ip.fw_pip.id
  }

  # CONFIGURATION DE MANAGEMENT 
  management_ip_configuration {
    name                 = "mgmt-config"
    subnet_id            = azurerm_subnet.fw_mgmt_subnet.id
    public_ip_address_id = azurerm_public_ip.fw_mgmt_pip.id
  }



  depends_on = [
    azurerm_resource_group.rg,
    azurerm_subnet.fw_subnet,
    azurerm_subnet.fw_mgmt_subnet,
    azurerm_public_ip.fw_pip,
    azurerm_public_ip.fw_mgmt_pip
  ]
}

resource "azurerm_monitor_diagnostic_setting" "fw_diagnostics" {
  name                       = "diag-firewall-to-sentinel"
  target_resource_id         = azurerm_firewall.fw.id
  log_analytics_workspace_id = "/subscriptions/42c20bc6-0b17-4863-9dd7-36fb9fb16729/resourceGroups/rg-aks-siso/providers/Microsoft.OperationalInsights/workspaces/law-aks-project"
  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}