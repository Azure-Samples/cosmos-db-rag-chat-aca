@description('Name of the Azure Container Registry')
param acrName string = 'blazorchataacr${uniqueString(resourceGroup().id)}'

@description('Name of the Container App')
param containerAppName string = 'blazorchataapp${uniqueString(resourceGroup().id)}'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Container image to deploy - defaults to hello-world for initial deployment')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Name of the Cosmos DB account')
param cosmosDbAccountName string = 'blazorchat-cosmos-${uniqueString(resourceGroup().id)}'

@description('Name of the Cosmos DB database')
param cosmosDbDatabaseName string = 'ChatDatabase'

@description('Name of the Cosmos DB container')
param cosmosDbContainerName string = 'ChatMessages'

@description('Name of the Azure OpenAI service')
param openAiName string = 'blazorchat-openai-${uniqueString(resourceGroup().id)}'

// User-assigned managed identity for Container App
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'blazorchat-identity-${uniqueString(resourceGroup().id)}'
  location: location
}

// Container App module for hosting the Blazor application
module containerApp 'modules/container-app.bicep' = {
  name: 'containerapp-deployment'
  params: {
    location: location
    containerImage: containerImage
    acrName: acrName
    containerAppName: containerAppName
    userAssignedIdentityId: userAssignedIdentity.id
    userAssignedIdentityPrincipalId: userAssignedIdentity.properties.principalId
    userAssignedIdentityClientId: userAssignedIdentity.properties.clientId
    cosmosDbAccountName: cosmosDbAccountName
    cosmosDbDatabaseName: cosmosDbDatabaseName
    cosmosDbContainerName: cosmosDbContainerName
    openAiName: openAiName
  }
}

// Cosmos DB module for storing chat messages and vector data
module cosmosDb 'modules/cosmos-db.bicep' = {
  name: 'cosmosdb-deployment'
  params: {
    location: location
    cosmosDbAccountName: cosmosDbAccountName
    cosmosDbDatabaseName: cosmosDbDatabaseName
    cosmosDbContainerName: cosmosDbContainerName
  }
}

// Azure OpenAI module for AI chat functionality
module openAi 'modules/openai.bicep' = {
  name: 'openai-deployment'
  params: {
    location: location
    openAiName: openAiName
  }
}

// Grant Container App managed identity access to Cosmos DB
resource cosmosDbRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cosmosDbAccountName, userAssignedIdentity.id, '5bd9cd88-fe45-4216-938b-f97437e15450')
  scope: resourceGroup()
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '5bd9cd88-fe45-4216-938b-f97437e15450') // DocumentDB Account Contributor
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    cosmosDb
  ]
}

// Grant Container App managed identity access to OpenAI
resource openAiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAiName, userAssignedIdentity.id, 'a97b65f3-24c7-4388-baec-2e87135dc908')
  scope: resourceGroup()
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') // Cognitive Services User
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    openAi
  ]
}

output containerAppFqdn string = containerApp.outputs.containerAppFqdn
output acrLoginServer string = containerApp.outputs.acrLoginServer
output acrName string = containerApp.outputs.acrName
output containerAppName string = containerApp.outputs.containerAppName
output cosmosDbAccountName string = cosmosDbAccountName
output cosmosDbDatabaseName string = cosmosDbDatabaseName
output cosmosDbContainerName string = cosmosDbContainerName
output openAiName string = openAiName
