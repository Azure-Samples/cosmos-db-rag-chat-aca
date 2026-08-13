param location string
param openAiName string

resource openai 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: openAiName
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: openAiName  // Required for OpenAI services
    disableLocalAuth: false  // Allow both AAD and key-based auth for flexibility
    publicNetworkAccess: 'Enabled'
  }
}

// Chat completion model deployment (GPT-5.1)
resource chatDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openai
  name: 'gpt-5.1'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5.1'
      version: '2025-11-13'
    }
    raiPolicyName: 'Microsoft.DefaultV2'
  }
  sku: {
    name: 'Standard'
    capacity: 10
  }
}

// Embedding model deployment for vector search
resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openai
  name: 'text-embedding-ada-002'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-ada-002'
      version: '2'
    }
    raiPolicyName: 'Microsoft.DefaultV2'
  }
  sku: {
    name: 'Standard'
    capacity: 10
  }
  dependsOn: [
    chatDeployment  // Deploy sequentially to avoid conflicts
  ]
}

// Outputs for reference (avoid outputting sensitive keys in production)
output serviceName string = openai.name
output endpoint string = openai.properties.endpoint
output chatDeploymentName string = chatDeployment.name
output embeddingDeploymentName string = embeddingDeployment.name
output resourceId string = openai.id
