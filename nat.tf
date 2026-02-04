# Public IPs (N)
resource "azurerm_public_ip" "nat" {
  for_each = local.nat_pip_count > 0 ? { for i in range(local.nat_pip_count) : i => i } : {}

  name                = format("pip-%s-nat-%03d", local.prefix, each.key + 1)
  location            = local.rg_loc
  resource_group_name = local.rg_name

  allocation_method = "Static"
  sku               = "Standard"

  tags = local.tags
}

# Public IP Prefix (1)
resource "azurerm_public_ip_prefix" "nat" {
  count = local.nat_prefix_enabled ? 1 : 0

  name                = "pippre-${local.prefix}-nat-001"
  location            = local.rg_loc
  resource_group_name = local.rg_name

  prefix_length = local.nat_prefix_length
  sku           = "Standard"

  tags = local.tags
}

resource "azurerm_nat_gateway" "this" {
  count = var.nat_gateway.enabled ? 1 : 0

  name                = "nat-${local.prefix}-001"
  location            = local.rg_loc
  resource_group_name = local.rg_name

  sku_name                = "Standard"
  idle_timeout_in_minutes = try(var.nat_gateway.idle_timeout_minutes, 10)

  tags = local.tags
}

# Associate all created public IPs
resource "azurerm_nat_gateway_public_ip_association" "this" {
  for_each = azurerm_public_ip.nat

  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = each.value.id
}

# Associate prefix (if enabled)
resource "azurerm_nat_gateway_public_ip_prefix_association" "this" {
  count = local.nat_prefix_enabled ? 1 : 0

  nat_gateway_id      = azurerm_nat_gateway.this[0].id
  public_ip_prefix_id = azurerm_public_ip_prefix.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  for_each = var.nat_gateway.enabled ? toset(try(var.nat_gateway.subnet_names, [])) : toset([])

  subnet_id      = azurerm_subnet.this[each.value].id
  nat_gateway_id = azurerm_nat_gateway.this[0].id

  depends_on = [
    azurerm_nat_gateway_public_ip_association.this,
    azurerm_nat_gateway_public_ip_prefix_association.this
  ]
}
