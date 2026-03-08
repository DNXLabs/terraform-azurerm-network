resource "azurerm_resource_group" "this" {
  count    = var.resource_group.create ? 1 : 0
  name     = var.resource_group.name
  location = var.resource_group.location
  tags     = local.tags
}

# Validations for NAT Gateway outbound IP config
resource "terraform_data" "validate_nat" {
  input = {
    enabled         = var.nat_gateway.enabled
    pip_enabled     = local.nat_pip_enabled
    pip_count       = local.nat_pip_count
    prefix_enabled  = local.nat_prefix_enabled
    prefix_length   = local.nat_prefix_length
    prefix_ip_count = local.nat_prefix_ip_count
    total_ip_count  = local.nat_total_ip_count
  }

  lifecycle {
    # NAT enabled => must have at least 1 outbound IP (pip or prefix)
    precondition {
      condition     = !var.nat_gateway.enabled || local.nat_total_ip_count >= 1
      error_message = "nat_gateway: enabled=true requires at least one outbound IP. Configure public_ip.enabled (+count) and/or public_ip_prefix.enabled."
    }

    # Prefix length allowed (IPv4): /28.. /31 (docs list these for Standard NAT)
    precondition {
      condition = !local.nat_prefix_enabled || (local.nat_prefix_length != null && local.nat_prefix_length >= 28 && local.nat_prefix_length <= 31)
      error_message = "nat_gateway: public_ip_prefix.prefix_length must be between 28 and 31 for IPv4 NAT scaling."
    }

    # Total allocated IP addresses <= 16
    precondition {
      condition     = !var.nat_gateway.enabled || local.nat_total_ip_count <= 16
      error_message = "nat_gateway: total allocated outbound IPs (public IPs + prefix addresses) must be <= 16."
    }
  }
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${local.prefix}-001"
  location            = local.rg_loc
  resource_group_name = local.rg_name
  address_space       = var.vnet.address_space
  dns_servers         = try(var.vnet.dns_servers, null)
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  for_each = local.subnets_by_name

  name                 = each.value.name
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_prefixes

  service_endpoints = try(each.value.service_endpoints, null)

  dynamic "delegation" {
    for_each = coalesce(try(each.value.delegations, null), [])
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }
}

resource "azurerm_network_security_group" "this" {
  for_each = local.nsg_subnets

  name                = coalesce(try(each.value.nsg.name, null), "nsg-${local.prefix}-${each.key}-001")
  location            = local.rg_loc
  resource_group_name = local.rg_name
  tags                = local.tags
}

# Do NOT associate NSG to AzureBastionSubnet automatically (Bastion compliance requirements)
resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = {
    for k, v in azurerm_network_security_group.this :
    k => v
    if k != "AzureBastionSubnet"
  }

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = each.value.id
}

resource "azurerm_network_security_rule" "this" {
  for_each = local.nsg_rules

  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol

  resource_group_name         = local.rg_name
  network_security_group_name = azurerm_network_security_group.this[each.value.subnet_name].name

  # Ensure Azure always gets a SourcePortRange/SourcePortRanges.
  source_port_ranges = try(each.value.source_port_ranges, null)
  source_port_range  = try(each.value.source_port_ranges, null) == null ? coalesce(try(each.value.source_port_range, null), "*") : null

  destination_port_ranges = try(each.value.destination_port_ranges, null)
  destination_port_range  = try(each.value.destination_port_ranges, null) == null ? try(each.value.destination_port_range, null) : null

  source_address_prefix        = try(each.value.source_address_prefix, null)
  source_address_prefixes      = try(each.value.source_address_prefixes, null)
  destination_address_prefix   = try(each.value.destination_address_prefix, null)
  destination_address_prefixes = try(each.value.destination_address_prefixes, null)

  description = try(each.value.description, null)
}
