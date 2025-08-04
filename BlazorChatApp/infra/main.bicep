@description('Location for all resources')
param location string = resourceGroup().location

@description('Container image to deploy - defaults to hello-world for initial deployment')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Environment name (e.g., dev, prod)')
param environmentName string = 'dev'

@description('Name of the Azure Container Registry')
param acrName string = ''

@description('Name of the Container App')
param containerAppName string = ''

@description('Name of the Cosmos DB account')
param cosmosDbAccountName string = ''

@description('Name of the Cosmos DB database')
param cosmosDbDatabaseName string = 'vectordb'

@description('Name of the Cosmos DB container')
param cosmosDbContainerName string = 'Container3'

@description('Name of the Azure OpenAI service')
param openAiName string = ''

// Resource token for consistent naming
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location, environmentName)

// Computed resource names if not provided
var actualAcrName = !empty(acrName) ? acrName : 'blazorchataacr${resourceToken}'
var actualContainerAppName = !empty(containerAppName) ? containerAppName : 'blazorchataapp${resourceToken}'
var actualCosmosDbAccountName = !empty(cosmosDbAccountName) ? cosmosDbAccountName : 'blazorchat-cosmos-${resourceToken}'
var actualOpenAiName = !empty(openAiName) ? openAiName : 'blazorchat-openai-${resourceToken}'

// Target scope and tags
targetScope = 'resourceGroup'

// Add required tags for the resource group
resource resourceGroupTags 'Microsoft.Resources/tags@2021-04-01' = {
  name: 'default'
  properties: {
    tags: {
      'azd-env-name': environmentName
    }
  }
}

// User-assigned managed identity for Container App
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'blazorchat-identity-${resourceToken}'
  location: location
}

// Container App module for hosting the Blazor application
module containerApp 'modules/container-app.bicep' = {
  name: 'containerapp-deployment'
  params: {
    location: location
    containerImage: containerImage
    acrName: actualAcrName
    containerAppName: actualContainerAppName
    userAssignedIdentityId: userAssignedIdentity.id
    userAssignedIdentityPrincipalId: userAssignedIdentity.properties.principalId
    userAssignedIdentityClientId: userAssignedIdentity.properties.clientId
    cosmosDbAccountName: actualCosmosDbAccountName
    cosmosDbDatabaseName: cosmosDbDatabaseName
    cosmosDbContainerName: cosmosDbContainerName
    openAiChatDeploymentName: openAi.outputs.chatDeploymentName
    openAiEmbeddingDeploymentName: openAi.outputs.embeddingDeploymentName
    openAiEndpoint: openAi.outputs.endpoint
  }
}

// Cosmos DB module for storing chat messages and vector data
module cosmosDb 'modules/cosmos-db.bicep' = {
  name: 'cosmosdb-deployment'
  params: {
    location: location
    cosmosDbAccountName: actualCosmosDbAccountName
    cosmosDbDatabaseName: cosmosDbDatabaseName
    cosmosDbContainerName: cosmosDbContainerName
  }
}

// Azure OpenAI module for AI chat functionality
module openAi 'modules/openai.bicep' = {
  name: 'openai-deployment'
  params: {
    location: location
    openAiName: actualOpenAiName
  }
}

// Reference to the Cosmos DB account for role assignment
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
  name: actualCosmosDbAccountName
  dependsOn: [
    cosmosDb
  ]
}

// Grant Container App managed identity access to Cosmos DB
resource cosmosDbRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
  name: guid(actualCosmosDbAccountName, userAssignedIdentity.id, '00000000-0000-0000-0000-000000000002')
  parent: cosmosDbAccount
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    roleDefinitionId: '${cosmosDbAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
    scope: cosmosDbAccount.id
  }
}

// Grant Container App managed identity access to OpenAI
resource openAiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(actualOpenAiName, userAssignedIdentity.id, '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  scope: resourceGroup()
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd') // Cognitive Services OpenAI User
    principalType: 'ServicePrincipal'
  }
}

output containerAppFqdn string = containerApp.outputs.containerAppFqdn
output acrLoginServer string = containerApp.outputs.acrLoginServer
output acrName string = containerApp.outputs.acrName
output containerAppName string = containerApp.outputs.containerAppName
output cosmosDbAccountName string = actualCosmosDbAccountName
output cosmosDbDatabaseName string = cosmosDbDatabaseName
output cosmosDbContainerName string = cosmosDbContainerName
output openAiName string = actualOpenAiName
output openAiEndpoint string = openAi.outputs.endpoint
output openAiChatDeploymentName string = openAi.outputs.chatDeploymentName
output openAiEmbeddingDeploymentName string = openAi.outputs.embeddingDeploymentName

// Required outputs for deployment
output RESOURCE_GROUP_ID string = resourceGroup().id
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerApp.outputs.acrLoginServer
