data "azurerm_client_config" "current" {}

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