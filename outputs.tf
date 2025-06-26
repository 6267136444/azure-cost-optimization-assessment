output "cosmosdb_endpoint" {
  value = azurerm_cosmosdb_account.cosmos.endpoint
}

output "storage_account_url" {
  value = azurerm_storage_account.blob.primary_blob_endpoint
}

output "function_app_url" {
  value = azurerm_linux_function_app.archive_function.default_hostname
}
