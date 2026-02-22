param name string
param location string = resourceGroup().location
param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

// File share for OnlyOffice data persistence
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storage.name}/default/onlyoffice-data'
  properties: {
    shareQuota: 100
    enabledProtocols: 'SMB'
  }
}

// File share for document cache
resource cacheShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storage.name}/default/onlyoffice-cache'
  properties: {
    shareQuota: 50
    enabledProtocols: 'SMB'
  }
}

// File share for logs
resource logsShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storage.name}/default/onlyoffice-logs'
  properties: {
    shareQuota: 10
    enabledProtocols: 'SMB'
  }
}

output name string = storage.name
output id string = storage.id
output primaryKey string = storage.listKeys().keys[0].value
