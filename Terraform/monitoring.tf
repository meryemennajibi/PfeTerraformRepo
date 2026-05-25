# =========================================================
# 1. Création du Log Analytic Workspace
# =========================================================

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-aks-siso-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}


# =========================================================
# 2. Création de Sentinel
# =========================================================
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_id = azurerm_log_analytics_workspace.law.id

  depends_on = [
    azurerm_log_analytics_workspace.law
  ]
}


# =========================================================
# 3. Diagnostic Settings du NSG
# =========================================================
resource "azurerm_monitor_diagnostic_setting" "nsg_security_logs" {
  name                       = "diag-nsg-security-events"
  target_resource_id         = azurerm_network_security_group.aks_nsg.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }

  depends_on = [
    azurerm_network_security_group.aks_nsg,
    azurerm_log_analytics_workspace.law
  ]
}

# =========================================================
# 4. Diagnostic Settings Azure Firewall
# =========================================================

resource "azurerm_monitor_diagnostic_setting" "fw_diagnostics" {
  name                       = "diag-firewall-to-sentinel"
  target_resource_id         = azurerm_firewall.fw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# 2. Logs administratifs AzureActivity
resource "azurerm_monitor_diagnostic_setting" "subscription_activity_logs" {
  name                       = "diag-subscription-activity-to-law"
  target_resource_id         = data.azurerm_subscription.current.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Security"
  }

  enabled_log {
    category = "Policy"
  }

  enabled_log {
    category = "Recommendation"
  }
}



