terraform {
  required_version = ">= 1.3"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.117"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  tags = {
    environment = "dev"
  }
  ssh_private_key_path = pathexpand(var.ssh_key_path)
}

resource "azurerm_resource_group" "mtc_rg" {
  name     = "mtc-resources"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "mtc_vn" {
  name                = "mtc-network"
  resource_group_name = azurerm_resource_group.mtc_rg.name
  location            = azurerm_resource_group.mtc_rg.location
  address_space       = ["10.123.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "mtc_subnet" {
  name                 = "mtc-subnet"
  resource_group_name  = azurerm_resource_group.mtc_rg.name
  virtual_network_name = azurerm_virtual_network.mtc_vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "mtc_sg" {
  name                = "mtc-sg"
  location            = azurerm_resource_group.mtc_rg.location
  resource_group_name = azurerm_resource_group.mtc_rg.name
  tags                = local.tags
}

# Only SSH, and only from the addresses you list in allowed_ssh_cidrs.
resource "azurerm_network_security_rule" "mtc_ssh" {
  name                        = "mtc-allow-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.allowed_ssh_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mtc_rg.name
  network_security_group_name = azurerm_network_security_group.mtc_sg.name
}

resource "azurerm_subnet_network_security_group_association" "mtc_sga" {
  subnet_id                 = azurerm_subnet.mtc_subnet.id
  network_security_group_id = azurerm_network_security_group.mtc_sg.id
}

# Basic SKU public IPs were retired in September 2025; Standard must be Static.
resource "azurerm_public_ip" "mtc_ip" {
  name                    = "mtc-ip"
  location                = azurerm_resource_group.mtc_rg.location
  resource_group_name     = azurerm_resource_group.mtc_rg.name
  sku                     = "Standard"
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30
  tags                    = local.tags
}

resource "azurerm_network_interface" "mtc_nic" {
  name                = "mtc-nic"
  location            = azurerm_resource_group.mtc_rg.location
  resource_group_name = azurerm_resource_group.mtc_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mtc_ip.id
  }

  tags = local.tags
}

resource "azurerm_linux_virtual_machine" "mtc_vm" {
  name                  = "mtc-vm"
  resource_group_name   = azurerm_resource_group.mtc_rg.name
  location              = azurerm_resource_group.mtc_rg.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.mtc_nic.id]

  custom_data = base64encode(templatefile("${path.module}/customdata.tpl", {
    user = var.admin_username
  }))

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("${local.ssh_private_key_path}.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # Adds an entry for the VM to your local ~/.ssh/config.
  provisioner "local-exec" {
    command = templatefile("${path.module}/${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address
      user         = var.admin_username
      identityfile = local.ssh_private_key_path
    })
    interpreter = var.host_os == "windows" ? ["powershell", "-Command"] : ["bash", "-c"]
  }

  tags = local.tags
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.mtc_vm.name}: ${azurerm_public_ip.mtc_ip.ip_address}"
}

# Resource addresses were renamed from hyphens to underscores; these keep
# existing deployments from destroying and recreating everything.
moved {
  from = azurerm_resource_group.mtc-rg
  to   = azurerm_resource_group.mtc_rg
}

moved {
  from = azurerm_virtual_network.mtc-vn
  to   = azurerm_virtual_network.mtc_vn
}

moved {
  from = azurerm_subnet.mtc-subnet
  to   = azurerm_subnet.mtc_subnet
}

moved {
  from = azurerm_network_security_group.mtc-sg
  to   = azurerm_network_security_group.mtc_sg
}

moved {
  from = azurerm_subnet_network_security_group_association.mtc-sga
  to   = azurerm_subnet_network_security_group_association.mtc_sga
}

moved {
  from = azurerm_public_ip.mtc-ip
  to   = azurerm_public_ip.mtc_ip
}

moved {
  from = azurerm_network_interface.mtc-nic
  to   = azurerm_network_interface.mtc_nic
}

moved {
  from = azurerm_linux_virtual_machine.mtc-vm
  to   = azurerm_linux_virtual_machine.mtc_vm
}
