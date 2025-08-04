param location string
param containerImage string
param acrName string
param containerAppName string
param userAssignedIdentityId string
param userAssignedIdentityPrincipalId string
param userAssignedIdentityClientId string
param cosmosDbAccountName string
param cosmosDbDatabaseName string
param cosmosDbContainerName string
param openAiChatDeploymentName string
param openAiEmbeddingDeploymentName string
param openAiEndpoint string

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false  // Better security practice
  }
}

// Grant AcrPull permission to the managed identity
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, userAssignedIdentityId, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  scope: acr
  properties: {
    principalId: userAssignedIdentityPrincipalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull role
    principalType: 'ServicePrincipal'
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource containerEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'blazorchatenv${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: {
    'azd-service-name': 'web'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
          allowedHeaders: ['*']
          allowCredentials: false
        }
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: userAssignedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'blazorchataapp'
          image: containerImage  // Use parameter for flexible deployment
          env: [
            {
              name: 'AZURE_CLIENT_ID'
              value: userAssignedIdentityClientId
            }
            {
              name: 'COSMOS_DB__ENDPOINT_DB'
              value: 'https://${cosmosDbAccountName}.documents.azure.com:443/'
            }
            {
              name: 'COSMOSDB_DATABASE_NAME'
              value: cosmosDbDatabaseName
            }
            {
              name: 'COSMOSDB_CONTAINER_NAME'
              value: cosmosDbContainerName
            }
            {
              name: 'OpenAI__ENDPOINT'
              value: openAiEndpoint
            }
            {
              name: 'OpenAI__DEPLOYMENT_NAME'
              value: openAiChatDeploymentName
            }
            {
              name: 'OpenAI__MODEL_ID'
              value: openAiChatDeploymentName
            }
            {
              name: 'OPENAI_CHAT_DEPLOYMENT_NAME'
              value: openAiChatDeploymentName
            }
            {
              name: 'OPENAI_EMBEDDING_DEPLOYMENT_NAME'
              value: openAiEmbeddingDeploymentName
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
      }
    }
  }
}

// Outputs for main.bicep to use
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn
output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
output containerAppName string = containerApp.name
