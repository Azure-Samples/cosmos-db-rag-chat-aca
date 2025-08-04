param location string
param cosmosDbAccountName string
param cosmosDbDatabaseName string
param cosmosDbContainerName string

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: cosmosDbAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    capabilities: [
      {
        name: 'EnableServerless'
      }
      {
        name: 'EnableNoSQLVectorSearch'  // Enable vector search capabilities
      }
    ]
    // Enhanced security settings
    disableLocalAuth: false  // Explicitly enable key-based auth for compatibility
    enableAnalyticalStorage: false
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    // Disable public network access to force private access
    publicNetworkAccess: 'Enabled'  // Keep enabled for Container Apps access
  }
}

resource db 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  parent: cosmosDb
  name: cosmosDbDatabaseName
  properties: {
    resource: {
      id: cosmosDbDatabaseName
    }
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  parent: db
  name: cosmosDbContainerName
  properties: {
    resource: {
      id: cosmosDbContainerName
      partitionKey: {
        paths: ['/partitionKey']
        kind: 'Hash'
      }
      // Vector search configuration for AI embeddings
      vectorEmbeddingPolicy: {
        vectorEmbeddings: [
          {
            path: '/titleVector'
            dataType: 'float32'
            distanceFunction: 'cosine'
            dimensions: 1536  // Standard OpenAI embedding dimension
          }
        ]
      }
    }
  }
}

// Additional container for chat messages (if needed by the application)
resource chatMessagesContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  parent: db
  name: 'ChatMessages'
  properties: {
    resource: {
      id: 'ChatMessages'
      partitionKey: {
        paths: ['/partitionKey']
        kind: 'Hash'
      }
    }
  }
}

// Outputs for reference (avoid outputting sensitive keys in production)
output accountName string = cosmosDb.name
output databaseName string = db.name
output containerName string = container.name
output endpoint string = cosmosDb.properties.documentEndpoint
output cosmosDbAccount object = cosmosDb
