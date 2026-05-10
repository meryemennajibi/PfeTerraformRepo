terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }

    azuread = {
      source = "hashicorp/azuread"
    }

    random = {
      source = "hashicorp/random"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    helm = {
      source = "hashicorp/helm"
    }

    tls = {
      source = "hashicorp/tls"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}