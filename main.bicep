@description('The name of the web application')
param appName string

@description('The location where the resources will be deployed')
param location string = resourceGroup().location

@description('The App Service Plan pricing tier')
@allowed([
  'F1'  // Free
  'B1'  // Basic
  'S1'  // Standard
  'P1'  // Premium
])
param appServicePlanSku string = 'F1'

@description('The .NET runtime version for the web app')
param dotnetVersion string = 'net8.0'

@description('Environment name for resource naming')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string = 'dev'

@description('Tags to apply to all resources')
param tags object = {
  Application: 'Demoappaz204'
  Environment: environment
  Owner: 'CloudThat'
}

// Variables for resource naming
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)
var webAppName = '${appName}-${environment}-${uniqueSuffix}'
var appServicePlanName = '${appName}-plan-${environment}-${uniqueSuffix}'
var appInsightsName = '${appName}-insights-${environment}-${uniqueSuffix}'
var logAnalyticsName = '${appName}-logs-${environment}-${uniqueSuffix}'

// Log Analytics Workspace for Application Insights
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights for monitoring
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
    tier: appServicePlanSku == 'F1' ? 'Free' : (appServicePlanSku == 'B1' ? 'Basic' : (appServicePlanSku == 'S1' ? 'Standard' : 'Premium'))
  }
  kind: 'app'
  properties: {
    reserved: false // Windows hosting
  }
}

// Web App
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  tags: tags
  kind: 'app'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnet'
        }
      ]
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: environment == 'prod' ? 'Production' : 'Development'
        }
        {
          name: 'ASPNETCORE_URLS'
          value: 'https://+:443;http://+:80'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
      alwaysOn: appServicePlanSku != 'F1' // Always On not available in Free tier
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      use32BitWorkerProcess: appServicePlanSku == 'F1' // Use 32-bit for Free tier
      webSocketsEnabled: false
      requestTracingEnabled: true
      httpLoggingEnabled: true
      logsDirectorySizeLimit: 35
      detailedErrorLoggingEnabled: true
      publishingUsername: '$${webAppName}'
      scmType: 'None'
    }
    clientAffinityEnabled: false
    publicNetworkAccess: 'Enabled'
    redundancyMode: 'None'
  }
}

// Web App deployment slot for staging (only if not using Free tier)
resource stagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = if (appServicePlanSku != 'F1') {
  parent: webApp
  name: 'staging'
  location: location
  tags: tags
  kind: 'app'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Staging'
        }
      ]
    }
  }
}

// Outputs
@description('The URL of the deployed web application')
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'

@description('The name of the created web app')
output webAppName string = webApp.name

@description('The resource ID of the web app')
output webAppId string = webApp.id

@description('The Application Insights connection string')
@secure()
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString

@description('The staging slot URL (if created)')
output stagingSlotUrl string = appServicePlanSku != 'F1' ? 'https://${stagingSlot.properties.defaultHostName}' : 'Not available in Free tier'

@description('The resource group name where resources were deployed')
output resourceGroupName string = resourceGroup().name
