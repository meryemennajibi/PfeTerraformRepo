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
#  2. Groupe de règles Firewall
# =========================================================
resource "azurerm_firewall_policy_rule_collection_group" "rules" {
  name               = "rcg-juiceshop"
  firewall_policy_id = azurerm_firewall_policy.fw_policy.id
  priority           = 100

  # =========================================================
  #  DNAT : Exposer l'application
  # =========================================================
  nat_rule_collection {
    name     = "dnat-juiceshop"
    priority = 100
    action   = "Dnat"

    rule {
      name                = "allow-http-inbound"
      protocols           = ["TCP"]
      source_addresses    = ["*"]
      destination_address = azurerm_public_ip.fw_pip.ip_address
      destination_ports   = ["80"]
      translated_address  = "10.0.1.6"
      translated_port     = "80"
    }

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
  #  TEMPORAIRE : Autoriser tout le trafic sortant AKS
  # =========================================================
  network_rule_collection {
    name     = "temporary-allow-all-outbound"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "allow-all-outbound"
      protocols             = ["Any"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }
}