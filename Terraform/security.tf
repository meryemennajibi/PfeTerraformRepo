data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}


# =========================================================
# 1. Network Security Group - Sécurisation du sous-réseau AKS
# =========================================================

resource "azurerm_network_security_group" "aks_nsg" {
  name                = "nsg-aks-main"
  location            = var.location
  resource_group_name = "rg-aks-siso"

  tags = {
    Project   = "PFE-Cloud-Security"
    ManagedBy = "Terraform"
  }

  depends_on = [azurerm_resource_group.rg]
}

# =========================================================
# 2. Règles NSG entrantes
# =========================================================


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



# =========================================================
# 3. Association du NSG au subnet AKS
# =========================================================

resource "azurerm_subnet_network_security_group_association" "aks_nsg_assoc" {
  subnet_id                 = azurerm_subnet.aks_subnet.id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id

  depends_on = [
    azurerm_network_security_group.aks_nsg,
    azurerm_subnet.aks_subnet
  ]
}


# =========================================================
# 4. Network Security Group pour Kali
# =========================================================

resource "azurerm_network_security_group" "kali_nsg" {
  name                = "nsg-kali"
  location            = var.location
  resource_group_name = var.resource_group_name
}



resource "azurerm_network_security_rule" "allow_ssh_kali" {
  name                        = "Allow-SSH-MyIP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "41.249.169.102/32"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.kali_nsg.name
}


# =========================================================
# 5. Azure Firewall - Adresses IP publiques
# =========================================================

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

# =========================================================
# 6. Azure Firewall
# =========================================================

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
# 9. Firewall Rules - DNAT, Network Rules et Application Rules
# =========================================================

resource "azurerm_firewall_policy_rule_collection_group" "rules" {
  name               = "rcg-juiceshop"
  firewall_policy_id = azurerm_firewall_policy.fw_policy.id
  priority           = 100

  # =========================================================
  #  DNAT : Exposer l' application (Ingress NGINX)
  # =========================================================
  nat_rule_collection {
    name     = "dnat-juiceshop"
    priority = 100
    action   = "Dnat"

    rule {
      name                = "allow-https-from-f5-waf"
      protocols           = ["TCP"]
      source_addresses    = ["20.98.161.2"] #F5 public IP 
      destination_address = azurerm_public_ip.fw_pip.ip_address
      destination_ports   = ["443"]
      translated_address  = "10.0.1.6"
      translated_port     = "443"
    }
  }


  # =========================================================
  #  NETWORK RULES 
  # =========================================================
  network_rule_collection {
    name     = "aks-network-rules"
    priority = 200
    action   = "Allow"

    # DNS
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

    #  HTTPS outbound 
    rule {
      name                  = "allow-https-outbound"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["*"]
      destination_ports     = ["443"]
    }

    #  HTTP
    rule {
      name                  = "allow-http-outbound"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["*"]
      destination_ports     = ["80"]
    }


    #  External AKS IP access inbound
    rule {
      name                  = "allow-aks"
      protocols             = ["TCP"]
      source_addresses      = ["20.98.161.2"]
      destination_addresses = ["10.0.1.0/24"]
      destination_ports     = ["443"]
    }

    rule {
      name                  = "test-analyst-blocked-change"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["8.8.8.8"]
      destination_ports     = ["443"]
    }
  }

  # =========================================================
  #  APPLICATION RULES (FQDN filtering)
  # =========================================================
  application_rule_collection {
    name     = "aks-app-rules"
    priority = 300
    action   = "Allow"

    rule {
      name             = "allow-aks-required-fqdns"
      source_addresses = ["10.0.1.0/24"]

      destination_fqdns = [
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com",
        "management.azure.com",
        "login.microsoftonline.com",
        "*.blob.core.windows.net",
        "*.ubuntu.com",
        "security.ubuntu.com"
      ]

      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

# =========================================================
# 10. Key Vault
# =========================================================

resource "azurerm_key_vault" "kv" {
  name                        = "kv-siso-${random_string.suffix.result}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
  soft_delete_retention_days  = 7
  enable_rbac_authorization   = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge"
    ]
  }
}

# =========================================================
# 11. Certificat TLS 
# =========================================================
resource "tls_private_key" "dummy" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "dummy" {
  private_key_pem = tls_private_key.dummy.private_key_pem

  subject {
    common_name  = "dummy.local"
    organization = "dummy.local"
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

# =========================================================
# 12. Stockage du certificat TLS dans Azure Key Vault
# =========================================================

resource "azurerm_key_vault_secret" "dummy_tls_key" {
  name         = "dummy-tls-key"
  value        = tls_private_key.dummy.private_key_pem
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "dummy_tls_cert" {
  name         = "dummy-tls-cert"
  value        = tls_self_signed_cert.dummy.cert_pem
  key_vault_id = azurerm_key_vault.kv.id
}


# =========================================================
# 13. Création du secret TLS dans Kubernetes
# =========================================================

resource "kubernetes_secret" "dummy_tls" {
  metadata {
    name = "dummy-tls"
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = azurerm_key_vault_secret.dummy_tls_cert.value
    "tls.key" = azurerm_key_vault_secret.dummy_tls_key.value
  }

  depends_on = [
    azurerm_key_vault_secret.dummy_tls_cert,
    azurerm_key_vault_secret.dummy_tls_key
  ]
}