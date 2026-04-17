# =========================================================
#  1. Firewall Policy
# =========================================================
resource "azurerm_firewall_policy" "fw_policy" {
  name                = "fwpolicy-juiceshop"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
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
      name                = "allow-https-inbound"
      protocols           = ["TCP"]
      source_addresses    = ["*"]
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
      source_addresses      = ["*"]
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