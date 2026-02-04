resource "azurerm_virtual_network_peering" "this" {
  for_each = { for p in var.peerings : p.name => p }

  name                      = each.value.name
  resource_group_name       = local.rg_name
  virtual_network_name      = azurerm_virtual_network.this.name
  remote_virtual_network_id = each.value.remote_virtual_network_id

  allow_virtual_network_access = try(each.value.allow_virtual_network_access, true)
  allow_forwarded_traffic      = try(each.value.allow_forwarded_traffic, false)
  allow_gateway_transit        = try(each.value.allow_gateway_transit, false)
  use_remote_gateways          = try(each.value.use_remote_gateways, false)
}
