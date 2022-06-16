# terraform-module-postgresql-flexible
Terraform module for [Azure Database for PostgreSQL - Flexible Server](https://docs.microsoft.com/en-us/azure/postgresql/flexible-server/)

## Example

```hcl
data "azurerm_subnet" "this" {
  name                 = "postgresql"
  resource_group_name  = "ss-${var.env}-network-rg"
  virtual_network_name = "ss-${var.env}-vnet"
}

module "postgresql" {
  source = "git@github.com:hmcts/terraform-module-postgresql-flexible?ref=master"
  env    = var.env

  product   = var.product
  component = var.component

  pgsql_databases = [
    {
      name : "application"
    }
  ]
  # TODO this will be removed in a follow-up
  pgsql_delegated_subnet_id = data.azurerm_subnet.this.id
  # Set your PostgreSQL version, note AzureAD auth requires version 12 (and not 11 or 13 currently)
  pgsql_version             = "12"

  common_tags = var.common_tags
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 3.7.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 3.7.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.2.0 |

## Resources

| Name | Type |
|------|------|
| [azurerm_postgresql_flexible_server.pgsql_server](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server) | resource |
| [azurerm_postgresql_flexible_server_configuration.pgsql_server_config](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server_configuration) | resource |
| [azurerm_postgresql_flexible_server_database.pg_databases](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server_database) | resource |
| [azurerm_postgresql_flexible_server_firewall_rule.pg_firewall_rules](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server_firewall_rule) | resource |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [random_password.password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [azurerm_subnet.pg_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Backup retention period in days for the PGSql instance. Valid values are between 7 & 35 days | `number` | `7` | no |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Common tag to be applied to resources. | `map(string)` | n/a | yes |
| <a name="input_component"></a> [component](#input\_component) | https://hmcts.github.io/glossary/#component | `string` | n/a | yes |
| <a name="input_create_mode"></a> [create\_mode](#input\_create\_mode) | The creation mode which can be used to restore or replicate existing servers | `string` | `"Default"` | no |
| <a name="input_env"></a> [env](#input\_env) | Environment value. | `string` | n/a | yes |
| <a name="input_geo_redundant_backups"></a> [geo\_redundant\_backups](#input\_geo\_redundant\_backups) | Enable geo-redundant backups for the PGSql instance. | `bool` | `false` | no |
| <a name="input_location"></a> [location](#input\_location) | Target Azure location to deploy the resource | `string` | `"UK South"` | no |
| <a name="input_name"></a> [name](#input\_name) | The default name will be product+component+env, you can override the product+component part by setting this | `string` | `""` | no |
| <a name="input_pgsql_admin_username"></a> [pgsql\_admin\_username](#input\_pgsql\_admin\_username) | Admin username | `string` | `"pgadmin"` | no |
| <a name="input_pgsql_databases"></a> [pgsql\_databases](#input\_pgsql\_databases) | Databases for the pgsql instance. | `list(object({ name : string, collation : optional(string), charset : optional(string) }))` | n/a | yes |
| <a name="input_pgsql_delegated_subnet_id"></a> [pgsql\_delegated\_subnet\_id](#input\_pgsql\_delegated\_subnet\_id) | PGSql delegated subnet id. | `string` | n/a | yes |
| <a name="input_pgsql_firewall_rules"></a> [pgsql\_firewall\_rules](#input\_pgsql\_firewall\_rules) | Postgres firewall rules | `list(object({ name : string, start_ip_address : string, end_ip_address : string }))` | `[]` | no |
| <a name="input_pgsql_server_configuration"></a> [pgsql\_server\_configuration](#input\_pgsql\_server\_configuration) | Postgres server configuration | `list(object({ name : string, value : string }))` | <pre>[<br>  {<br>    "name": "backslash_quote",<br>    "value": "on"<br>  }<br>]</pre> | no |
| <a name="input_pgsql_sku"></a> [pgsql\_sku](#input\_pgsql\_sku) | The PGSql flexible server instance sku | `string` | `"GP_Standard_D2s_v3"` | no |
| <a name="input_pgsql_storage_mb"></a> [pgsql\_storage\_mb](#input\_pgsql\_storage\_mb) | Max storage allowed for the PGSql Flexibile instance | `number` | `65536` | no |
| <a name="input_pgsql_version"></a> [pgsql\_version](#input\_pgsql\_version) | The PGSql flexible server instance version. | `string` | n/a | yes |
| <a name="input_product"></a> [product](#input\_product) | https://hmcts.github.io/glossary/#product | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Project name - sds or cft. | `any` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of existing resource group to deploy resources into | `string` | `null` | no |
| <a name="input_restore_time"></a> [restore\_time](#input\_restore\_time) | The point in time to restore. Only used when create mode is set to PointInTimeRestore | `any` | `null` | no |
| <a name="input_source_server_id"></a> [source\_server\_id](#input\_source\_server\_id) | Source server ID for point in time restore. Only used when create mode is set to PointInTimeRestore | `any` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | n/a |
| <a name="output_password"></a> [password](#output\_password) | n/a |
| <a name="output_resource_group_location"></a> [resource\_group\_location](#output\_resource\_group\_location) | n/a |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | n/a |
<!-- END_TF_DOCS -->

## Contributing

We use pre-commit hooks for validating the terraform format and maintaining the documentation automatically.
Install it with:

```shell
$ brew install pre-commit terraform-docs
$ pre-commit install
```

If you add a new hook make sure to run it against all files:
```shell
$ pre-commit run --all-files
```
