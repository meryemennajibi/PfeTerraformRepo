# =========================================================
#  1. Firewall Policy (obligatoire pour Azure Firewall Basic)
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
  #  DNAT : Exposer ton application (Ingress NGINX)
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
  #  NETWORK RULES : Communication réseau essentielle AKS
  # =========================================================
  network_rule_collection {
    name     = "aks-network-rules"
    priority = 200
    action   = "Allow"

    # -----------------------------------------
    #  DNS  sortant (Network rule)
    # -----------------------------------------
    rule {
      name                  = "allow-dns-and-https-outbound"
      protocols             = ["UDP", "TCP"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }

    # -----------------------------------------
    # Autoriser API Kubernetes  (Network rule)
    # -----------------------------------------
    rule {
      name                  = "allow-aks-api"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["10.1.0.0/16"]
      destination_ports     = ["443"]
    }

    # ----------------------------------------------------------
    #  CRITIQUE : Communication interne entre les composants AKS
    # ----------------------------------------------------------
    rule {
      name                  = "allow-aks-internal-communication"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["10.0.0.0/16"]
      destination_ports     = ["443", "10250"]
    }

  }

  # =========================================================
  #  APPLICATION RULES : Accès Internet (Docker, Helm, Azure)
  # =========================================================
  application_rule_collection {
    name     = "aks-app-rules"
    priority = 300
    action   = "Allow"

    rule {
      name             = "allow-external-services"
      source_addresses = ["10.0.1.0/24"]

      destination_fqdns = [

        "registry.k8s.io",
        "*.registry.k8s.io",

        # backend réel utilisé par registry.k8s.io
        "*.pkg.dev",
        "us-east4-docker.pkg.dev",
        "*.amazonaws.com",
        "*.s3.amazonaws.com",
        "*.s3.dualstack.us-east-1.amazonaws.com",
        "*.pkg.dev",

        #  Docker / Images
        "quay.io",
        "*.quay.io",

        "*.docker.io",
        "production.cloudflare.docker.com",

        #  GitHub (Helm charts, manifests)
        "github.com",
        "*.githubusercontent.com",

        #  Cert-manager (Let's Encrypt)
        "acme-v02.api.letsencrypt.org",

        #  Azure
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com",
        "management.azure.com",
        "login.microsoftonline.com",
        "*.hcp.${var.location}.azmk8s.io"
      ]

      # HTTP + HTTPS
      protocols {
        port = "80"
        type = "Http"
      }

      protocols {
        port = "443"
        type = "Https"
      }
    }
  }
}