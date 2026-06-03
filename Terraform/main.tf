resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# =========================================================
#  Réseau virtuel principal
# =========================================================


resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-projet-siso"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]

  depends_on = [
    azurerm_resource_group.rg
  ]
}


# =========================================================
#  Sous-réseau AKS
# =========================================================

resource "azurerm_subnet" "aks_subnet" {
  name                 = "snet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}


# =========================================================
#  Sous-réseau Kali
# =========================================================

resource "azurerm_subnet" "kali_subnet" {
  name                 = "snet-kali"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.4.0/24"]
}


# =========================================================
#  Sous-réseau Azure Firewall
# =========================================================

resource "azurerm_subnet" "fw_subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/26"]
}


# =========================================================
#  Sous-réseau de management Azure Firewall
# =========================================================


resource "azurerm_subnet" "fw_mgmt_subnet" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/26"]
}


# =========================================================
#  Table de routage AKS
# =========================================================


resource "azurerm_route_table" "aks_udr" {
  name                = "rt-aks"
  location            = var.location
  resource_group_name = var.resource_group_name

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
  }
}


# =========================================================
#  Association de la table de routage au sous-réseau AKS
# =========================================================


resource "azurerm_subnet_route_table_association" "aks_assoc" {
  subnet_id      = azurerm_subnet.aks_subnet.id
  route_table_id = azurerm_route_table.aks_udr.id
}

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}


# =========================================================
#  Network Security Group - Sécurisation du sous-réseau AKS
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
#  Règles NSG entrantes
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
#  Association du NSG au subnet AKS
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
#  Network Security Group pour Kali
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
#  Azure Firewall - Adresses IP publiques
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
#  Azure Firewall
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
#   Firewall Policy
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
#  Firewall Rules - DNAT, Network Rules et Application Rules
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

# =========================================================
# 1. Rôle administrateur AKS
# =========================================================


resource "azurerm_role_assignment" "aks_admin_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.aks_admin_group_object_id
}


# =========================================================
# 2. Rôle administrateur Firewall
# =========================================================


resource "azurerm_role_assignment" "firewall_admin_network_contributor" {
  scope                = azurerm_firewall.fw.id
  role_definition_name = "Network Contributor"
  principal_id         = var.firewall_admin_group_object_id
}


# =========================================================
# Accès Firewall pour l’analyste sécurité
# =========================================================

#resource "azurerm_role_assignment" "security_analyst_firewall_network_contributor" {
#  scope                = azurerm_firewall.fw.id
#  role_definition_name = "Network Contributor"
#  principal_id         = var.security_analyst_group_object_id
#}


# =========================================================
# 3. Rôle analyste sécurité sur Sentinel / Log Analytics
# =========================================================


resource "azurerm_role_assignment" "security_analyst_law" {
  scope                = azurerm_log_analytics_workspace.law.id
  role_definition_name = "Microsoft Sentinel Responder"
  principal_id         = var.security_analyst_group_object_id
}


# =========================================================
# 4. Accès Key Vault pour l’administrateur cloud
# =========================================================


resource "azurerm_role_assignment" "admin_keyvault_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.cloud_admin_object_id
}


# =========================================================
# 5. Permission réseau pour l’identité managée AKS
# =========================================================


resource "azurerm_role_assignment" "aks_network_contributor_subnet" {
  scope                = azurerm_subnet.aks_subnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

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

  # ==================================================
  # Authentification Entra ID + Azure RBAC
  # ==================================================
  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    admin_group_object_ids = [var.aks_admin_group_object_id]
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

  # ==========================================
  # Supervision Container Insights
  # ==========================================
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }

  # ================================
  # Intégration Key Vault CSI Driver
  # ================================
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  depends_on = [
    azurerm_resource_group.rg,
    azurerm_log_analytics_workspace.law,
  ]
}

# ==================================================
# Ingress
# ==================================================

resource "kubernetes_namespace_v1" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  namespace  = kubernetes_namespace_v1.ingress_nginx.metadata[0].name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  wait    = true
  timeout = 900

  set = [
    {
      name  = "controller.publishService.enabled"
      value = "true"
    },
    {
      name  = "controller.service.externalTrafficPolicy"
      value = "Local"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
      value = azurerm_kubernetes_cluster.aks.node_resource_group
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
      value = "true"
    }
  ]

  depends_on = [
    kubernetes_namespace_v1.ingress_nginx,
    azurerm_role_assignment.aks_network_contributor_subnet
  ]
}


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


# =========================================================
# 1. Adresse IP publique pour la VM Kali
# =========================================================


resource "azurerm_public_ip" "kali_pip" {
  name                = "pip-kali"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on          = [azurerm_resource_group.rg]
}


# =========================================================
# 4. Association du NSG au sous-réseau Kali
# =========================================================


resource "azurerm_subnet_network_security_group_association" "kali_nsg_assoc" {
  subnet_id                 = azurerm_subnet.kali_subnet.id
  network_security_group_id = azurerm_network_security_group.kali_nsg.id
}


# =========================================================
# 5. Interface réseau de la VM Kali
# =========================================================


resource "azurerm_network_interface" "kali_nic" {
  name                = "nic-kali"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig-kali"
    subnet_id                     = azurerm_subnet.kali_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.kali_pip.id
  }
}


# =========================================================
# 6. Machine virtuelle Kali Linux
# =========================================================


resource "azurerm_linux_virtual_machine" "kali_vm" {
  name                = "vm-kali"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_D4ds_v4"
  admin_username      = "kaliuser"

  network_interface_ids = [
    azurerm_network_interface.kali_nic.id
  ]

  disable_password_authentication = false
  admin_password                  = var.kali_admin_paswd

  os_disk {
    name                 = "osdisk-kali"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 58
  }

  source_image_reference {
    publisher = "kali-linux"
    offer     = "kali"
    sku       = "kali-2026-1"
    version   = "2026.1.0"
  }

  plan {
    name      = "kali-2026-1"
    product   = "kali"
    publisher = "kali-linux"
  }
}






