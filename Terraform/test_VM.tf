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


