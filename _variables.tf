variable "naming" {
  description = "Azure taxonomy inputs."
  type = object({
    org      = string
    env      = string
    region   = string
    workload = string
  })
}

variable "resource_group" {
  description = "Create or use an existing resource group."
  type = object({
    create   = bool
    name     = string
    location = optional(string)
  })
}

variable "tags" {
  description = "Extra tags merged with default taxonomy tags."
  type        = map(string)
  default     = {}
}

variable "vnet" {
  description = "VNet config."
  type = object({
    address_space = list(string)
    dns_servers   = optional(list(string))
  })
}

variable "subnets" {
  description = "Subnets list. If nsg is provided, a NSG will be created and associated (except AzureBastionSubnet)."
  type = list(object({
    name             = string
    address_prefixes = list(string)

    service_endpoints = optional(list(string))

    delegations = optional(list(object({
      name = string
      service_delegation = object({
        name    = string
        actions = list(string)
      })
    })))

    nsg = optional(object({
      rules = optional(list(object({
        name                         = string
        priority                     = number
        direction                    = string
        access                       = string
        protocol                     = string
        source_port_range            = optional(string)
        source_port_ranges           = optional(list(string))
        destination_port_range       = optional(string)
        destination_port_ranges      = optional(list(string))
        source_address_prefix        = optional(string)
        source_address_prefixes      = optional(list(string))
        destination_address_prefix   = optional(string)
        destination_address_prefixes = optional(list(string))
        description                  = optional(string)
      })), [])
    }))
  }))
}

variable "nat_gateway" {
  description = "NAT Gateway configuration. Supports combining public IPs and public IP prefixes, total allocated IPs <= 16."
  type = object({
    enabled              = bool
    idle_timeout_minutes = optional(number, 10)
    subnet_names         = optional(list(string), [])

    # Public IPs (can be multiple)
    public_ip = optional(object({
      enabled = bool
      count   = optional(number, 1)
    }))

    # Public IP Prefix
    public_ip_prefix = optional(object({
      enabled       = bool
      prefix_length = number
    }))
  })
  default = {
    enabled = false
  }
}

variable "peerings" {
  description = "Peerings created from this VNet to remote VNets."
  type = list(object({
    name                         = string
    remote_virtual_network_id    = string
    allow_virtual_network_access = optional(bool, true)
    allow_forwarded_traffic      = optional(bool, false)
    allow_gateway_transit        = optional(bool, false)
    use_remote_gateways          = optional(bool, false)
  }))
  default = []
}
