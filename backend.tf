terraform {
  backend "azurerm" {
    resource_group_name  = "rg-aks-siso"
    storage_account_name = "sttfstatepfe001"
    container_name       = "tfstate"
    key                  = "pfe.tfstate"
  }
}