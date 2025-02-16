locals {
  default_name           = var.component != "" ? "${var.product}-${var.component}" : var.product
  name                   = var.name != "" ? var.name : local.default_name
  server_name            = "${local.name}-${var.env}"
  postgresql_rg_name     = var.resource_group_name == null ? azurerm_resource_group.rg[0].name : var.resource_group_name
  postgresql_rg_location = var.resource_group_name == null ? azurerm_resource_group.rg[0].location : var.location
  vnet_rg_name           = var.business_area == "sds" ? "ss-${var.env}-network-rg" : "core-infra-${var.env}"
  vnet_name              = var.business_area == "sds" ? "ss-${var.env}-vnet" : "core-infra-vnet-${var.env}"

  private_dns_zone_id = "/subscriptions/1baf5470-1c3e-40d3-a6f7-74bfbce4b348/resourceGroups/core-infra-intsvc-rg/providers/Microsoft.Network/privateDnsZones/private.postgres.database.azure.com"

  is_prod        = length(regexall(".*(prod).*", var.env)) > 0
  admin_group    = local.is_prod ? (var.add_multiple_admin_groups ? split(",", join(",", ["DTS Platform Operations SC", var.additional_admin_groups])) : split(",", "DTS Platform Operations SC")) : (var.add_multiple_admin_groups ? split(",", join(",", ["DTS Platform Operations", var.additional_admin_groups])) : split(",", "DTS Platform Operations"))
  db_reader_user = local.is_prod ? (var.add_multiple_readonly_groups ? split(",", join(",", ["DTS JIT Access ${var.product} DB Reader SC", var.additional_readonly_groups])) : split(",", "DTS JIT Access ${var.product} DB Reader SC")) : (var.add_multiple_readonly_groups ? split(",", join(",", ["DTS ${upper(var.business_area)} DB Access Reader", var.additional_readonly_groups])) : split(",", "DTS ${upper(var.business_area)} DB Access Reader"))

}

data "azurerm_subnet" "pg_subnet" {
  name                 = "postgresql"
  resource_group_name  = local.vnet_rg_name
  virtual_network_name = local.vnet_name

  count = var.pgsql_delegated_subnet_id == "" ? 1 : 0
}

data "azurerm_client_config" "current" {}

data "azuread_group" "db_admin" {
  count            = length(local.admin_group)
  display_name     = local.admin_group[count.index]
  security_enabled = true
}

data "azuread_service_principal" "mi_name" {
  count     = var.enable_read_only_group_access ? 1 : 0
  object_id = var.admin_user_object_id
}

resource "random_password" "password" {
  length = 20
  # safer set of special characters for pasting in the shell
  override_special = "()-_"
}

resource "azurerm_postgresql_flexible_server" "pgsql_server" {
  name                = local.server_name
  resource_group_name = local.postgresql_rg_name
  location            = local.postgresql_rg_location
  version             = var.pgsql_version

  create_mode                       = var.create_mode
  point_in_time_restore_time_in_utc = var.restore_time
  source_server_id                  = var.source_server_id

  delegated_subnet_id = var.pgsql_delegated_subnet_id == "" ? data.azurerm_subnet.pg_subnet[0].id : var.pgsql_delegated_subnet_id
  private_dns_zone_id = local.private_dns_zone_id

  administrator_login    = var.pgsql_admin_username
  administrator_password = random_password.password.result

  storage_mb = var.pgsql_storage_mb

  sku_name = var.pgsql_sku

  authentication {
    active_directory_auth_enabled = true
    tenant_id                     = data.azurerm_client_config.current.tenant_id
    password_auth_enabled         = true
  }

  tags = var.common_tags

  high_availability {
    mode = "ZoneRedundant"
  }

  maintenance_window {
    day_of_week  = "0"
    start_hour   = "03"
    start_minute = "00"
  }

  lifecycle {
    ignore_changes = [
      zone,
      high_availability.0.standby_availability_zone,
    ]
  }

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backups

}

resource "azurerm_postgresql_flexible_server_configuration" "pgsql_server_config" {
  for_each = {
    for index, config in var.pgsql_server_configuration :
    config.name => config
  }

  name      = each.value.name
  server_id = azurerm_postgresql_flexible_server.pgsql_server.id
  value     = each.value.value
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "pgsql_adadmin" {
  count               = length(local.admin_group)
  server_name         = azurerm_postgresql_flexible_server.pgsql_server.name
  resource_group_name = azurerm_postgresql_flexible_server.pgsql_server.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azuread_group.db_admin[count.index].object_id
  principal_name      = local.admin_group[count.index]
  principal_type      = "Group"
  depends_on = [
    azurerm_postgresql_flexible_server.pgsql_server
  ]
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "pgsql_principal_admin" {
  count               = var.enable_read_only_group_access ? 1 : 0
  server_name         = azurerm_postgresql_flexible_server.pgsql_server.name
  resource_group_name = azurerm_postgresql_flexible_server.pgsql_server.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = var.admin_user_object_id
  principal_name      = data.azuread_service_principal.mi_name[0].display_name
  principal_type      = "ServicePrincipal"
  depends_on = [
    azurerm_postgresql_flexible_server_active_directory_administrator.pgsql_adadmin
  ]
}

resource "null_resource" "set-user-permissions-additionaldbs" {
  count = var.enable_read_only_group_access ? length(local.db_reader_user) : 0

  triggers = {
    script_hash    = filesha256("${path.module}/set-postgres-permissions.bash")
    name           = local.name
    db_reader_user = local.db_reader_user[count.index]
  }

  provisioner "local-exec" {
    command = "${path.module}/set-postgres-permissions.bash"

    environment = {
      DB_HOST_NAME   = azurerm_postgresql_flexible_server.pgsql_server.fqdn
      DB_USER        = "${data.azuread_service_principal.mi_name[0].display_name}"
      DB_READER_USER = local.db_reader_user[count.index]
      DB_NAME        = azurerm_postgresql_flexible_server.pgsql_server.name
    }
  }
  depends_on = [
    azurerm_postgresql_flexible_server_active_directory_administrator.pgsql_principal_admin
  ]
}
