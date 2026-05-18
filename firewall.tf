data "azurerm_subscription" "current" {}


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

# 1. Logs réseau / règles Azure Firewall
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

# =========================================================
#  1. Firewall Policy
# =========================================================
resource "azurerm_firewall_policy" "fw_policy" {
  name                = "fwpolicy-juiceshop"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"

##chnagemet

  tags = {
    SecurityMonitoring = "Enabled"
    LastSecurityReview = "2026-05-18-v2"
  }

  depends_on          = [azurerm_resource_group.rg]
}

# =========================================================
#  2. Rule Collection Group
# =========================================================
resource "azurerm_firewall_policy_rule_collection_group" "rules" {
  name               = "rcg-juiceshop"
  firewall_policy_id = azurerm_firewall_policy.fw_policy.id
  priority           = 100

    # =========================================================
  #  DNAT : Exposer ton application (Ingress NGINX)
  # =========================================================
  nat_rule_collection {
    name     = "dnat-juiceshop"
    priority = 100
    action   = "Dnat"

    rule {
      name                = "allow-https-from-f5-waf"
      protocols           = ["TCP"]
      source_addresses    = ["*"] #F5 public IP 
      destination_address = azurerm_public_ip.fw_pip.ip_address
      destination_ports   = ["443"]
      translated_address  = "10.0.1.6"
      translated_port     = "443"
    }
  }


  # =========================================================
  # 🔵 NETWORK RULES (CRITICAL — DO NOT SKIP)
  # =========================================================
  network_rule_collection {
    name     = "aks-network-rules"
    priority = 200
    action   = "Allow"

    # ✅ DNS
    rule {
      name                  = "allow-dns"
      protocols             = ["UDP", "TCP"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }

    rule {
      name                  = "allow-aks-udp-1194"
      protocols             = ["UDP"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["*"]
      destination_ports     = ["1194"]
    }

    rule {
      name                  = "allow-aks-tcp-9000"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["*"]
      destination_ports     = ["9000"]
    }

    rule {
      name                  = "allow-ntp"
      protocols             = ["UDP"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }

    # ✅ HTTPS outbound 
    rule {
      name                  = "allow-https-outbound"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["*"]
      destination_ports     = ["443"]
    }

    # ✅ HTTP
    rule {
      name                  = "allow-http-outbound"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["*"]
      destination_ports     = ["80"]
    }


    # ✅ External AKS IP access inbound
    rule {
      name                  = "allow-aks"
      protocols             = ["TCP"]
      source_addresses      = ["20.98.161.2"]
      destination_addresses = ["10.0.1.0/24"]
      destination_ports     = ["443"]
    }
  }

  # =========================================================
  # 🟢 APPLICATION RULES (FQDN filtering)
  # =========================================================
  application_rule_collection {
    name     = "aks-app-rules"
    priority = 300
    action   = "Allow"

    rule {
      name             = "allow-aks-required-fqdns"
      source_addresses = ["10.0.1.0/24"]

      destination_fqdns = ["*"]

      protocols {
        type = "Http"
        port = 80
      }

      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}