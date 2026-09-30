variable "host_os" {
  description = "OS of the machine running Terraform; picks <host_os>-ssh-script.tpl."
  type        = string
  default     = "linux"

  validation {
    condition     = contains(["linux", "macos", "windows"], var.host_os)
    error_message = "host_os must be one of: linux, macos, windows."
  }
}

variable "allowed_ssh_cidrs" {
  description = "Source CIDRs allowed to SSH to the VM, e.g. [\"203.0.113.10/32\"]. Find your IP with `curl ifconfig.me`."
  type        = list(string)

  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0 && alltrue([for c in var.allowed_ssh_cidrs : can(cidrhost(c, 0))])
    error_message = "allowed_ssh_cidrs must be a non-empty list of valid CIDR blocks."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

variable "vm_size" {
  description = "VM size."
  type        = string
  default     = "Standard_F2"
}

variable "admin_username" {
  description = "Admin user on the VM."
  type        = string
  default     = "adminuser"
}

variable "ssh_key_path" {
  description = "Path to the SSH private key; the public key is read from <path>.pub."
  type        = string
  default     = "~/.ssh/mtcazurekey"
}
