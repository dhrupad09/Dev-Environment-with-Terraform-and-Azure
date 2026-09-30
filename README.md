[![CI](https://github.com/dhrupad09/Dev-Environment-with-Terraform-and-Azure/actions/workflows/blank.yml/badge.svg)](https://github.com/dhrupad09/Dev-Environment-with-Terraform-and-Azure/actions/workflows/blank.yml)
# Dev-Environment-with-Terraform-and-Azure

Terraform that builds an Ubuntu VM on Azure with Docker installed and adds an
entry for it to your local `~/.ssh/config`.

It creates a resource group, virtual network, subnet, network security group
(SSH only, from the addresses you allow), a static public IP, a NIC and a
Linux VM.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) 1.3 or later
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), logged in with `az login`
- An SSH key pair:

  ```sh
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/mtcazurekey
  ```

## Usage

```sh
cp example.tfvars terraform.tfvars   # then set your IP and host OS
terraform init
terraform apply
```

`terraform.tfvars` is git-ignored. The variables are:

| Variable            | Required | Default              | Notes                                         |
|---------------------|----------|----------------------|-----------------------------------------------|
| `allowed_ssh_cidrs` | yes      |                      | e.g. `["203.0.113.10/32"]` (`curl ifconfig.me`) |
| `host_os`           | no       | `linux`              | `linux`, `macos` or `windows`                 |
| `ssh_key_path`      | no       | `~/.ssh/mtcazurekey` | private key; `.pub` is read alongside it      |
| `location`          | no       | `eastus`             |                                               |
| `vm_size`           | no       | `Standard_F2`        |                                               |
| `admin_username`    | no       | `adminuser`          |                                               |

After apply, connect with `ssh <public-ip>` (the IP is in the
`public_ip_address` output), or pick the host in VS Code Remote-SSH.

Tear everything down with:

```sh
terraform destroy
```

## State

State files are git-ignored because they contain subscription and resource
details. For anything beyond a personal sandbox, store state in an Azure
Storage account by adding a backend block:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "<unique-name>"
    container_name       = "tfstate"
    key                  = "dev-environment.tfstate"
  }
}
```
