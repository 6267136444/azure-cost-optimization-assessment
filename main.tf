provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "rg-billing-optimization"
  location = "East US"
}

# Storage Account (Blob)
resource "azurerm_storage_account" "blob" {
  name                     = "billingstorageacct"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "archive" {
  name                  = "billing-archive"
  storage_account_name  = azurerm_storage_account.blob.name
  container_access_type = "private"
}

# Cosmos DB Account
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "billing-cosmosdb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  consistency_policy {
    consistency_level = "Session"
  }
  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }
}

# Cosmos DB Database + Container
resource "azurerm_cosmosdb_sql_database" "billingdb" {
  name                = "BillingDB"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

resource "azurerm_cosmosdb_sql_container" "billingcontainer" {
  name                = "BillingRecords"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.billingdb.name
  partition_key_path  = "/id"
}

# App Service Plan (for Function App)
resource "azurerm_app_service_plan" "function_plan" {
  name                = "billing-function-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "FunctionApp"
  reserved            = true
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

# Function App
resource "azurerm_linux_function_app" "archive_function" {
  name                       = "billing-archival-fn"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  service_plan_id            = azurerm_app_service_plan.function_plan.id
  storage_account_name       = azurerm_storage_account.blob.name
  storage_account_access_key = azurerm_storage_account.blob.primary_access_key
  os_type                    = "linux"
  site_config {
    application_stack {
      python_version = "3.10"
    }
  }
  app_settings = {
    "AzureWebJobsStorage" = azurerm_storage_account.blob.primary_connection_string
    "COSMOS_DB_NAME"      = azurerm_cosmosdb_sql_database.billingdb.name
    "ARCHIVE_CONTAINER"   = azurerm_storage_container.archive.name
  }
}
