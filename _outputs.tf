output "resource_group_name" {
  value = local.rg_name
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "subnet_ids" {
  value = { for k, v in azurerm_subnet.this : k => v.id }
}

output "nsg_ids" {
  value = { for k, v in azurerm_network_security_group.this : k => v.id }
}

output "nat_gateway_id" {
  value = try(azurerm_nat_gateway.this[0].id, null)
}

output "nat_public_ip_id" {
  value = try(azurerm_public_ip.nat[0].id, null)
}
