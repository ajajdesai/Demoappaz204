using 'main.bicep'

// Required parameters
param appName = 'demoappaz204'
param location = 'East US'

// Optional parameters - customize as needed
param appServicePlanSku = 'F1'  // Change to 'B1', 'S1', or 'P1' for production
param environment = 'dev'        // Change to 'staging' or 'prod' as needed
param dotnetVersion = 'net8.0'

// Resource tags
param tags = {
  Application: 'Modern E-Commerce Store'
  Environment: 'Development'
  Owner: 'CloudThat'
  Project: 'Demoappaz204'
  CostCenter: 'Demo'
}
