# terraform-azure-network

Terraform module for creating and managing Azure Virtual Networks with subnets, Network Security Groups, NAT Gateway, and VNet peering.

This module provides a comprehensive solution for Azure networking infrastructure, supporting both simple and complex network topologies with enterprise-grade security controls.

## Features

- **Virtual Network Management**: Create and configure Azure VNets with custom address spaces
- **Subnet Orchestration**: Define multiple subnets with individual configurations
- **Network Security Groups**: Automatic NSG creation and association per subnet with custom rules
- **NAT Gateway**: Optional NAT Gateway with support for multiple public IPs and IP prefixes
- **Subnet Delegation**: Support for service delegations (e.g., Azure Database, App Service)
- **VNet Peering**: Configure multiple peering connections to other VNets
- **Resource Group**: Create new or use existing resource groups
- **Tagging Strategy**: Built-in default tagging with custom tag support
- **Azure Bastion Support**: Proper handling of AzureBastionSubnet without automatic NSG association

## Usage

### Example 1 — Non-Prod (Basic VNet)

A simple VNet with two subnets for development environments.

```hcl
module "network" {
  source = "./modules/network"

  name = "mycompany-dev-aue-app"

  resource_group = {
    create   = true
    name     = "rg-mycompany-dev-aue-app-001"
    location = "australiaeast"
  }

  tags = {
    project     = "infrastructure"
    environment = "development"
  }

  vnet = {
    address_space = ["10.0.0.0/16"]
  }

  subnets = [
    {
      name             = "snet-web"
      address_prefixes = ["10.0.1.0/24"]
    },
    {
      name             = "snet-app"
      address_prefixes = ["10.0.2.0/24"]
    }
  ]

  nat_gateway = {
    enabled = false
  }

  peerings = []
}
```

### Example 2 — Production (NSG Rules, NAT Gateway, Delegation)

A production VNet with NSG rules per subnet, NAT Gateway for outbound traffic, subnet delegation for MySQL, and Bastion.

```hcl
module "network" {
  source = "./modules/network"

  name = "contoso-prod-aue-platform"

  resource_group = {
    create   = true
    name     = "rg-contoso-prod-aue-platform-001"
    location = "australiaeast"
  }

  tags = {
    project     = "platform-infrastructure"
    environment = "production"
    stack       = "network"
  }

  vnet = {
    address_space = ["172.16.0.0/22"]
  }

  subnets = [
    # Application Gateway subnet
    {
      name             = "snet-agw"
      address_prefixes = ["172.16.0.0/27"]

      nsg = {
        rules = [
          {
            name                       = "AllowVPNAdminInbound"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_address_prefix      = "192.168.0.0/16"
            destination_address_prefix = "172.16.0.0/27"
            destination_port_ranges    = ["22", "443"]
          },
          {
            name                       = "DenyAllInbound"
            priority                   = 4096
            direction                  = "Inbound"
            access                     = "Deny"
            protocol                   = "*"
            source_address_prefix      = "*"
            destination_address_prefix = "*"
            destination_port_range     = "*"
          }
        ]
      }
    },

    # Client subnet with NAT Gateway
    {
      name             = "snet-client"
      address_prefixes = ["172.16.0.64/26"]

      nsg = {
        rules = [
          {
            name                       = "AllowVPNAdminInbound"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_address_prefix      = "192.168.0.0/16"
            destination_address_prefix = "172.16.0.64/26"
            destination_port_ranges    = ["22", "3389"]
          },
          {
            name                       = "AllowInternetViaNAT"
            priority                   = 4090
            direction                  = "Outbound"
            access                     = "Allow"
            protocol                   = "*"
            source_address_prefix      = "*"
            destination_address_prefix = "Internet"
            destination_port_range     = "*"
          }
        ]
      }
    },

    # App subnet with NAT Gateway
    {
      name             = "snet-app"
      address_prefixes = ["172.16.0.128/26"]

      nsg = {
        rules = [
          {
            name                       = "AllowClientToApp"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_address_prefix      = "172.16.0.64/26"
            destination_address_prefix = "172.16.0.128/26"
            destination_port_ranges    = ["8080", "443"]
          },
          {
            name                       = "AllowInternetViaNAT"
            priority                   = 4090
            direction                  = "Outbound"
            access                     = "Allow"
            protocol                   = "*"
            source_address_prefix      = "*"
            destination_address_prefix = "Internet"
            destination_port_range     = "*"
          }
        ]
      }
    },

    # Database subnet with delegation
    {
      name             = "snet-data"
      address_prefixes = ["172.16.1.0/27"]

      delegations = [
        {
          name = "mysql-flex-delegation"
          service_delegation = {
            name    = "Microsoft.DBforMySQL/flexibleServers"
            actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
          }
        }
      ]

      nsg = {
        rules = [
          {
            name                       = "AllowAppToMySQL"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_address_prefix      = "172.16.0.128/26"
            destination_address_prefix = "172.16.1.0/27"
            destination_port_range     = "3306"
          }
        ]
      }
    },

    # Azure Bastion subnet
    {
      name             = "AzureBastionSubnet"
      address_prefixes = ["172.16.3.0/26"]
    }
  ]

  # NAT Gateway configuration
  nat_gateway = {
    enabled              = true
    idle_timeout_minutes = 4
    subnet_names         = ["snet-client", "snet-app"]

    public_ip = {
      enabled = true
      count   = 1
    }

    public_ip_prefix = {
      enabled       = true
      prefix_length = 30
    }
  }

  # VNet Peering
  peerings = []
}
```

### Example with VNet Peering

```hcl
module "network" {
  source = "./modules/network"

  name = "mycompany-prod-aue-hub"

  resource_group = {
    create   = true
    name     = "rg-mycompany-prod-aue-hub-001"
    location = "australiaeast"
  }

  vnet = {
    address_space = ["10.0.0.0/16"]
  }

  subnets = [
    {
      name             = "snet-shared"
      address_prefixes = ["10.0.1.0/24"]
    }
  ]

  nat_gateway = {
    enabled = false
  }

  peerings = [
    {
      name                         = "hub-to-spoke1"
      remote_virtual_network_id    = "/subscriptions/xxxxx/resourceGroups/rg-spoke1/providers/Microsoft.Network/virtualNetworks/vnet-spoke1"
      allow_virtual_network_access = true
      allow_forwarded_traffic      = true
      allow_gateway_transit        = true
      use_remote_gateways          = false
    }
  ]
}
```

### Using YAML Variables

Create a `vars/network.yaml` file:

```yaml
azure:
  subscription_id: "afb35bd4-145f-4a15-889e-5da052d030ce"
  location: australiaeast

network:
  name: managed-services-lab-aue-stg

  resource_group:
    create: true
    name: rg-managed-services-lab-aue-stg-001
    location: australiaeast

  tags:
    project: managed-services-lab
    environment: lab
    stack: network

  vnet:
    address_space:
      - 172.16.0.0/22

  subnets:
    - name: snet-stg-client
      address_prefixes: [172.16.0.64/26]
      nsg:
        rules:
          - name: AllowVPNAdminInbound
            priority: 100
            direction: Inbound
            access: Allow
            protocol: Tcp
            source_address_prefix: 192.168.0.0/16
            destination_address_prefix: 172.16.0.64/26
            destination_port_ranges: ["22", "3389"]

  nat_gateway:
    enabled: true
    idle_timeout_minutes: 4
    subnet_names:
      - snet-stg-client
    public_ip:
      enabled: true
      count: 1
```

Then use in your Terraform:

```hcl
locals {
  workspace = yamldecode(file("vars/network.yaml"))
}

module "network" {
  source = "./modules/network"

  name           = local.workspace.network.name
  resource_group = local.workspace.network.resource_group
  tags           = try(local.workspace.network.tags, {})
  vnet           = local.workspace.network.vnet
  subnets        = local.workspace.network.subnets
  nat_gateway    = try(local.workspace.network.nat_gateway, { enabled = false })
  peerings       = try(local.workspace.network.peerings, [])
}
```

## NAT Gateway Configuration

The module supports flexible NAT Gateway configuration with multiple outbound IP options:

### Public IPs Only

```hcl
nat_gateway = {
  enabled              = true
  idle_timeout_minutes = 10
  subnet_names         = ["snet-app", "snet-web"]

  public_ip = {
    enabled = true
    count   = 2  # Creates 2 public IPs
  }
}
```

### Public IP Prefix Only

```hcl
nat_gateway = {
  enabled              = true
  subnet_names         = ["snet-app"]

  public_ip_prefix = {
    enabled       = true
    prefix_length = 30  # Provides 4 IPs (2^(32-30))
  }
}
```

### Combined (Public IPs + Prefix)

```hcl
nat_gateway = {
  enabled              = true
  subnet_names         = ["snet-app", "snet-web"]

  public_ip = {
    enabled = true
    count   = 2
  }

  public_ip_prefix = {
    enabled       = true
    prefix_length = 31  # Provides 2 IPs (2^(32-31))
  }
  # Total: 4 IPs (2 from public_ip + 2 from prefix)
}
```

### NAT Gateway Validations

The module includes built-in validations:

- NAT Gateway enabled requires at least 1 outbound IP (public IP or prefix)
- Public IP prefix length must be between 28 and 31 (for IPv4)
- Total allocated IPs (public IPs + prefix addresses) must be ≤ 16

## Network Security Groups

### NSG Behavior

- NSGs are automatically created for subnets that define an `nsg` object
- NSG naming follows the pattern: `nsg-{name}-{subnet_name}-001`
- NSGs are automatically associated with their subnets, except for `AzureBastionSubnet`
- Azure Bastion subnet NSG association must be handled manually due to specific compliance requirements

### NSG Rule Examples

#### Port Range Example

```hcl
{
  name                       = "AllowHTTPSInbound"
  priority                   = 100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_address_prefix      = "Internet"
  destination_address_prefix = "VirtualNetwork"
  destination_port_ranges    = ["80", "443", "8080"]
}
```

#### Multiple Source Prefixes

```hcl
{
  name                         = "AllowMultipleSourcesInbound"
  priority                     = 200
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "*"
  source_address_prefixes      = ["10.0.0.0/16", "172.16.0.0/12"]
  destination_address_prefix   = "VirtualNetwork"
  destination_port_range       = "*"
}
```

#### Service Tags

```hcl
{
  name                       = "AllowAzureMonitor"
  priority                   = 200
  direction                  = "Outbound"
  access                     = "Allow"
  protocol                   = "*"
  source_address_prefix      = "*"
  destination_address_prefix = "AzureMonitor"
  destination_port_range     = "*"
}
```

## Subnet Delegation

For services that require subnet delegation (e.g., Azure Database, App Service):

```hcl
{
  name             = "snet-mysql"
  address_prefixes = ["10.0.3.0/27"]

  delegations = [
    {
      name = "mysql-delegation"
      service_delegation = {
        name    = "Microsoft.DBforMySQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  ]
}
```

Common delegation services:
- `Microsoft.DBforMySQL/flexibleServers`
- `Microsoft.DBforPostgreSQL/flexibleServers`
- `Microsoft.Web/serverFarms`
- `Microsoft.ContainerInstance/containerGroups`
- `Microsoft.Netapp/volumes`

## Naming Convention

Resources are named using the prefix pattern: `{name}`

Example:
- VNet: `vnet-{name}-001`
- NSG: `nsg-{name}-{subnet_name}-001`

## Tags

The module automatically applies default tags and merges with custom tags:

**Default tags** (applied automatically):
- `name`: from var.name
- `managedBy`: "terraform"

**Custom tags** (merged):
```hcl
tags = {
  project     = "my-project"
  cost_center = "12345"
  owner       = "platform-team"
}
```

## Outputs

| Name | Description |
|------|-------------|
| `resource_group_name` | The name of the resource group |
| `vnet_name` | The name of the virtual network |
| `vnet_id` | The ID of the virtual network |
| `subnet_ids` | Map of subnet names to subnet IDs |
| `nsg_ids` | Map of subnet names to NSG IDs |
| `nat_gateway_id` | The ID of the NAT Gateway (if enabled) |
| `nat_public_ip_id` | The ID of the first NAT Gateway public IP (if enabled) |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| azurerm | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | >= 4.0.0 |

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `name` | Resource name prefix for all resources | string | yes |
| `resource_group` | Resource group configuration | object | yes |
| `vnet` | Virtual network configuration | object | yes |
| `subnets` | List of subnet configurations | list(object) | yes |
| `tags` | Extra tags merged with default tags | map(string) | no |
| `nat_gateway` | NAT Gateway configuration | object | no |
| `peerings` | VNet peering configurations | list(object) | no |

### Detailed Input Specifications

#### resource_group

```hcl
object({
  create   = bool             # Create new RG or use existing
  name     = string           # Resource group name
  location = optional(string) # Required if create = true
})
```

#### vnet

```hcl
object({
  address_space = list(string)           # VNet address spaces
  dns_servers   = optional(list(string)) # Custom DNS servers
})
```

#### subnets

```hcl
list(object({
  name             = string       # Subnet name
  address_prefixes = list(string) # Subnet CIDR blocks

  service_endpoints = optional(list(string)) # Service endpoints

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
      direction                    = string  # Inbound or Outbound
      access                       = string  # Allow or Deny
      protocol                     = string  # Tcp, Udp, *, Icmp
      source_port_range            = optional(string)
      source_port_ranges           = optional(list(string))
      destination_port_range       = optional(string)
      destination_port_ranges      = optional(list(string))
      source_address_prefix        = optional(string)
      source_address_prefixes      = optional(list(string))
      destination_address_prefix   = optional(string)
      destination_address_prefixes = optional(list(string))
      description                  = optional(string)
    })))
  }))
}))
```

#### nat_gateway

```hcl
object({
  enabled              = bool
  idle_timeout_minutes = optional(number, 10)
  subnet_names         = optional(list(string), [])

  public_ip = optional(object({
    enabled = bool
    count   = optional(number, 1)
  }))

  public_ip_prefix = optional(object({
    enabled       = bool
    prefix_length = number  # 28-31 for IPv4
  }))
})
```

#### peerings

```hcl
list(object({
  name                         = string
  remote_virtual_network_id    = string
  allow_virtual_network_access = optional(bool, true)
  allow_forwarded_traffic      = optional(bool, false)
  allow_gateway_transit        = optional(bool, false)
  use_remote_gateways          = optional(bool, false)
}))
```

## Common Scenarios

### Hub-Spoke Network Topology

```hcl
# Hub VNet
module "hub_network" {
  source = "./modules/network"

  name = "contoso-prod-aue-hub"

  resource_group = {
    create   = true
    name     = "rg-contoso-prod-aue-hub-001"
    location = "australiaeast"
  }

  tags = {
    tier = "hub"
  }

  vnet = {
    address_space = ["10.0.0.0/16"]
  }

  subnets = [
    {
      name             = "AzureFirewallSubnet"
      address_prefixes = ["10.0.1.0/26"]
    },
    {
      name             = "AzureBastionSubnet"
      address_prefixes = ["10.0.2.0/26"]
    }
  ]

  nat_gateway = {
    enabled = false
  }

  # Peering from Hub to Spoke
  peerings = [
    {
      name                         = "hub-to-spoke"
      remote_virtual_network_id    = module.spoke_network.vnet_id
      allow_virtual_network_access = true
      allow_forwarded_traffic      = true
      allow_gateway_transit        = false
      use_remote_gateways          = false
    }
  ]
}

# Spoke VNet
module "spoke_network" {
  source = "./modules/network"

  name = "contoso-prod-aue-app1"

  resource_group = {
    create   = true
    name     = "rg-contoso-prod-aue-app1-001"
    location = "australiaeast"
  }

  tags = {
    tier = "spoke"
  }

  vnet = {
    address_space = ["10.1.0.0/16"]
  }

  subnets = [
    {
      name             = "snet-app"
      address_prefixes = ["10.1.1.0/24"]
    }
  ]

  nat_gateway = {
    enabled = false
  }

  # Peering from Spoke to Hub
  peerings = [
    {
      name                         = "spoke-to-hub"
      remote_virtual_network_id    = module.hub_network.vnet_id
      allow_virtual_network_access = true
      allow_forwarded_traffic      = true
      allow_gateway_transit        = false
      use_remote_gateways          = false
    }
  ]
}
```

### Multi-Tier Application Network

```hcl
module "app_network" {
  source = "./modules/network"

  name = "mycompany-prod-aue-webapp"

  resource_group = {
    create   = true
    name     = "rg-mycompany-prod-aue-webapp-001"
    location = "australiaeast"
  }

  vnet = {
    address_space = ["10.0.0.0/16"]
  }

  subnets = [
    # Web tier
    {
      name             = "snet-web"
      address_prefixes = ["10.0.1.0/24"]
      nsg = {
        rules = [
          {
            name                       = "AllowHTTPSInbound"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_address_prefix      = "Internet"
            destination_address_prefix = "10.0.1.0/24"
            destination_port_ranges    = ["80", "443"]
          }
        ]
      }
    },

    # Application tier
    {
      name             = "snet-app"
      address_prefixes = ["10.0.2.0/24"]
      nsg = {
        rules = [
          {
            name                       = "AllowFromWeb"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_address_prefix      = "10.0.1.0/24"
            destination_address_prefix = "10.0.2.0/24"
            destination_port_range     = "8080"
          }
        ]
      }
    },

    # Data tier (delegated for MySQL)
    {
      name             = "snet-data"
      address_prefixes = ["10.0.3.0/24"]

      delegations = [
        {
          name = "mysql-delegation"
          service_delegation = {
            name    = "Microsoft.DBforMySQL/flexibleServers"
            actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
          }
        }
      ]

      nsg = {
        rules = [
          {
            name                       = "AllowFromApp"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_address_prefix      = "10.0.2.0/24"
            destination_address_prefix = "10.0.3.0/24"
            destination_port_range     = "3306"
          }
        ]
      }
    }
  ]

  nat_gateway = {
    enabled      = true
    subnet_names = ["snet-app"]

    public_ip = {
      enabled = true
      count   = 1
    }
  }
}
```

## Best Practices

1. **Subnet Sizing**: Plan subnet sizes carefully considering future growth
2. **NSG Rules**: Use specific rules instead of broad wildcards when possible
3. **NAT Gateway**: Use for outbound internet connectivity instead of public IPs on VMs
4. **Tagging**: Always include meaningful tags for cost allocation and governance
5. **Naming**: Follow consistent naming conventions across all resources
6. **Security**: Implement least-privilege access with NSG rules
7. **Azure Bastion**: Always use /26 subnet size for AzureBastionSubnet
8. **Service Endpoints**: Enable for Azure services to improve performance and security

## License

Apache 2.0 Licensed. See LICENSE for full details.

## Authors

Module managed by DNX Solutions.

## Contributing

Please read CONTRIBUTING.md for details on our code of conduct and the process for submitting pull requests.