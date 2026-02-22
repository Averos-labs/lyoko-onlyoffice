param name string
param location string = resourceGroup().location
param tags object = {}
param containerAppsEnvironmentId string
param storageAccountName string
@secure()
param jwtSecret string

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      secrets: [
        {
          name: 'jwt-secret'
          value: jwtSecret
        }
        {
          name: 'storage-key'
          value: storage.listKeys().keys[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'onlyoffice-documentserver'
          image: 'onlyoffice/documentserver:latest'
          resources: {
            cpu: json('2.0')
            memory: '4Gi'
          }
          env: [
            {
              name: 'JWT_ENABLED'
              value: 'true'
            }
            {
              name: 'JWT_SECRET'
              secretRef: 'jwt-secret'
            }
            {
              name: 'JWT_HEADER'
              value: 'Authorization'
            }
            {
              name: 'JWT_IN_BODY'
              value: 'true'
            }
            {
              name: 'WOPI_ENABLED'
              value: 'false'
            }
          ]
          volumeMounts: [
            {
              volumeName: 'data'
              mountPath: '/var/www/onlyoffice/Data'
            }
            {
              volumeName: 'cache'
              mountPath: '/var/lib/onlyoffice'
            }
            {
              volumeName: 'logs'
              mountPath: '/var/log/onlyoffice'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 5
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
      volumes: [
        {
          name: 'data'
          storageType: 'AzureFile'
          storageName: 'onlyoffice-data'
        }
        {
          name: 'cache'
          storageType: 'AzureFile'
          storageName: 'onlyoffice-cache'
        }
        {
          name: 'logs'
          storageType: 'AzureFile'
          storageName: 'onlyoffice-logs'
        }
      ]
    }
  }
}

// Storage mounts for container app environment
resource dataStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  name: '${split(containerAppsEnvironmentId, '/')[8]}/onlyoffice-data'
  properties: {
    azureFile: {
      accountName: storage.name
      accountKey: storage.listKeys().keys[0].value
      shareName: 'onlyoffice-data'
      accessMode: 'ReadWrite'
    }
  }
}

resource cacheStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  name: '${split(containerAppsEnvironmentId, '/')[8]}/onlyoffice-cache'
  properties: {
    azureFile: {
      accountName: storage.name
      accountKey: storage.listKeys().keys[0].value
      shareName: 'onlyoffice-cache'
      accessMode: 'ReadWrite'
    }
  }
}

resource logsStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  name: '${split(containerAppsEnvironmentId, '/')[8]}/onlyoffice-logs'
  properties: {
    azureFile: {
      accountName: storage.name
      accountKey: storage.listKeys().keys[0].value
      shareName: 'onlyoffice-logs'
      accessMode: 'ReadWrite'
    }
  }
}

output id string = containerApp.id
output name string = containerApp.name
output url string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
