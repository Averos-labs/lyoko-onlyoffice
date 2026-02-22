targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment (used for resource naming)')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('JWT secret for OnlyOffice security')
@secure()
param jwtSecret string = newGuid()

@description('Id of the user or app to assign application roles')
param principalId string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Container Apps Environment
module containerAppsEnvironment './resources/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  scope: rg
  params: {
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
  }
}

// Storage Account for OnlyOffice data persistence
module storage './resources/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
  }
}

// OnlyOffice Container App
module onlyofficeApp './resources/container-app.bicep' = {
  name: 'onlyoffice-container-app'
  scope: rg
  params: {
    name: '${abbrs.appContainerApps}onlyoffice-${resourceToken}'
    location: location
    tags: tags
    containerAppsEnvironmentId: containerAppsEnvironment.outputs.id
    storageAccountName: storage.outputs.name
    jwtSecret: jwtSecret
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = rg.name
output ONLYOFFICE_URL string = onlyofficeApp.outputs.url
output ONLYOFFICE_JWT_ENABLED string = 'true'
