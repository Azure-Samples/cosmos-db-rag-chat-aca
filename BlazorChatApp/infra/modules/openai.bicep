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

// output endpoint string = openai.properties.endpoint
// output key string = listKeys(openai.id, openai.apiVersion).key1

// Outputs for reference (avoid outputting sensitive keys in production)
output serviceName string = openai.name
output endpoint string = openai.properties.endpoint
