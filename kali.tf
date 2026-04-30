

# Public IP for Kali
resource "azurerm_public_ip" "kali_pip" {
  name                = "pip-kali"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on          = [azurerm_resource_group.rg]
}

# NSG for Kali
resource "azurerm_network_security_group" "kali_nsg" {
  name                = "nsg-kali"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Allow SSH only from your public IP
resource "azurerm_network_security_rule" "allow_ssh_kali" {
  name                        = "Allow-SSH-MyIP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "41.251.213.203/32"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.kali_nsg.name
}

# Associate NSG with Kali subnet
resource "azurerm_subnet_network_security_group_association" "kali_nsg_assoc" {
  subnet_id                 = azurerm_subnet.kali_subnet.id
  network_security_group_id = azurerm_network_security_group.kali_nsg.id
}

# Network interface
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

# Kali Linux VM
resource "azurerm_linux_virtual_machine" "kali_vm" {
  name                = "vm-kali"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B2s"
  admin_username      = "kaliuser"

  network_interface_ids = [
    azurerm_network_interface.kali_nic.id
  ]

  disable_password_authentication = false

  admin_password = var.kali_admin_paswd

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

# Output public IP
output "kali_public_ip" {
  value = azurerm_public_ip.kali_pip.ip_address
}