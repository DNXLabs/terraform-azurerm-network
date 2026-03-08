locals {
  prefix = var.name

  default_tags = {
    name      = var.name
    managedBy = "terraform"
  }

  tags = merge(local.default_tags, var.tags)

  rg_name = var.resource_group.create ? azurerm_resource_group.this[0].name : data.azurerm_resource_group.existing[0].name
  rg_loc  = var.resource_group.create ? azurerm_resource_group.this[0].location : data.azurerm_resource_group.existing[0].location

  subnets_by_name = { for s in var.subnets : s.name => s }

  nsg_subnets = {
    for s in var.subnets :
    s.name => s
    if try(s.nsg, null) != null
  }

  nsg_rules = merge([
    for subnet_name, s in local.nsg_subnets : {
      for r in try(s.nsg.rules, []) :
      "${subnet_name}.${r.name}" => merge(r, { subnet_name = subnet_name })
    }
  ]...)

  rg_name_alias = var.resource_group.create ? azurerm_resource_group.this[0].name : data.azurerm_resource_group.existing[0].name
  rg_loc_alias  = var.resource_group.create ? azurerm_resource_group.this[0].location : data.azurerm_resource_group.existing[0].location

  # NAT config derived values
  nat_pip_enabled = var.nat_gateway.enabled && try(var.nat_gateway.public_ip.enabled, false)
  nat_pip_count   = local.nat_pip_enabled ? max(try(var.nat_gateway.public_ip.count, 1), 0) : 0

  nat_prefix_enabled = var.nat_gateway.enabled && try(var.nat_gateway.public_ip_prefix.enabled, false)
  nat_prefix_length  = local.nat_prefix_enabled ? try(var.nat_gateway.public_ip_prefix.prefix_length, 30) : 30

  # Prefix IPs = 2^(32 - prefix_length) for IPv4
  nat_prefix_ip_count = local.nat_prefix_enabled && local.nat_prefix_length != null ? pow(2, 32 - local.nat_prefix_length) : 0

  nat_total_ip_count = local.nat_pip_count + local.nat_prefix_ip_count
}
