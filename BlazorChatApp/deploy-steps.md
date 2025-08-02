# Deployment Steps for Blazor Cosmos Vector Chat App

This Blazor application integrates with Azure Cosmos DB for vector search and Azure OpenAI for chat completion. It provides a RAG (Retrieval-Augmented Generation) chat experience using hybrid search with RRF (Reciprocal Rank Fusion).

## Prerequisites

- Docker Desktop installed and running
- Azure CLI installed and logged in
- Azure subscription with access to:
  - Azure Cosmos DB (with vector search enabled)
  - Azure OpenAI Service
  - Azure Container Registry
  - Azure Container Apps

## 🐳 Local Development with Docker

### 1. Configure Application Settings

Ensure your `appsettings.json` contains the correct configuration:

```json
{
  "COSMOS_DB": {
    "ENDPOINT_DB": "https://your-cosmos-db.documents.azure.com:443/"
  },
  "OpenAI": {
    "DEPLOYMENT_NAME": "gpt-35-turbo",
    "ENDPOINT": "https://your-openai.openai.azure.com/",
    "API_KEY": "your-api-key",
    "MODEL_ID": "gpt-35-turbo"
  }
}
```

### 2. Build Docker Image

```bash
# Build the Docker image
docker build -t blazor-chat-app .
```

### 3. Run Locally

```bash
# Run the container
docker run -d -p 8080:8080 --name blazor-chat-container blazor-chat-app

# Check if container is running
docker ps

# View application logs
docker logs blazor-chat-container
```

### 4. Access the Application

- **Main App**: <http://localhost:8080>
- **Chat Interface**: <http://localhost:8080/chat>

### 5. Stop and Clean Up

```bash
# Stop the container
docker stop blazor-chat-container

# Remove the container
docker rm blazor-chat-container

# Remove the image (optional)
docker rmi blazor-chat-app
```

## ☁️ Azure Container Apps Deployment

### 1. Deploy Infrastructure First

```bash
# Deploy the infrastructure with placeholder image
az deployment group create \
  --resource-group <your-resource-group-name> \
  --template-file infra/main.bicep \
  --parameters containerImage='mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
```

### 2. Get ACR Login Server

```bash
# Get deployment outputs
ACR_NAME=$(az deployment group show --resource-group <your-resource-group-name> --name main --query properties.outputs.acrName.value -o tsv)
ACR_LOGIN_SERVER=$(az deployment group show --resource-group <your-resource-group-name> --name main --query properties.outputs.acrLoginServer.value -o tsv)

echo "ACR Name: $ACR_NAME"
echo "ACR Login Server: $ACR_LOGIN_SERVER"
```

### 3. Build and Push Application Image

```bash
# Login to Azure Container Registry
az acr login --name $ACR_NAME

# Build and tag the image for ACR
docker build -t $ACR_LOGIN_SERVER/blazor-cosmos-chat:latest .

# Push the image to ACR
docker push $ACR_LOGIN_SERVER/blazor-cosmos-chat:latest

# Verify the image was pushed
az acr repository list --name $ACR_NAME --output table
```

### 4. Update Container App

```bash
# Get container app name
CONTAINER_APP_NAME=$(az deployment group show --resource-group <your-resource-group-name> --name main --query properties.outputs.containerAppName.value -o tsv)

# Update the container app with your image
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group <your-resource-group-name> \
  --image $ACR_LOGIN_SERVER/blazor-cosmos-chat:latest

# Or alternatively, redeploy with your image
az deployment group create \
  --resource-group <your-resource-group-name> \
  --template-file infra/main.bicep \
  --parameters containerImage="$ACR_LOGIN_SERVER/blazor-cosmos-chat:latest"
```

### 5. Configure Environment Variables (if needed)

```bash
# If you need to set environment variables for Azure resources
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group <your-resource-group-name> \
  --set-env-vars \
    "ASPNETCORE_ENVIRONMENT=Production" \
    "COSMOS_DB__ENDPOINT_DB=https://your-cosmos-db.documents.azure.com:443/" \
    "OpenAI__ENDPOINT=https://your-openai.openai.azure.com/"
```

### 6. Configure Managed Identity for Cosmos DB Access

The application uses Azure Managed Identity to securely access Cosmos DB. You need to configure the necessary permissions:

```bash
# Get the container app's managed identity principal ID
PRINCIPAL_ID=$(az containerapp identity show --name $CONTAINER_APP_NAME --resource-group <your-resource-group-name> --query principalId -o tsv)

# Get your Cosmos DB account name (replace with your actual Cosmos DB account name)
COSMOS_DB_ACCOUNT_NAME="<your-cosmos-db-account-name>"

# Assign the "Cosmos DB Built-in Data Contributor" role to the container app's managed identity
az cosmosdb sql role assignment create \
  --account-name $COSMOS_DB_ACCOUNT_NAME \
  --resource-group <your-resource-group-name> \
  --scope "/" \
  --principal-id $PRINCIPAL_ID \
  --role-definition-id "00000000-0000-0000-0000-000000000002"

# Verify the role assignment
az cosmosdb sql role assignment list \
  --account-name $COSMOS_DB_ACCOUNT_NAME \
  --resource-group <your-resource-group-name> \
  --output table
```

> **📝 Note**: The role definition ID `00000000-0000-0000-0000-000000000002` corresponds to the "Cosmos DB Built-in Data Contributor" role, which provides read and write access to Cosmos DB data. If your container app doesn't have a managed identity enabled, it will be automatically created when you assign the role.

### 7. Get Application URL

```bash
# Get the application URL
FQDN=$(az deployment group show --resource-group <your-resource-group-name> --name main --query properties.outputs.containerAppFqdn.value -o tsv)
echo "🌐 Your application is available at: https://$FQDN"
echo "💬 Chat interface: https://$FQDN/chat"
```

### 8. Monitor Deployment

```bash
# Check container app status
az containerapp show --name $CONTAINER_APP_NAME --resource-group <your-resource-group-name> --query "properties.provisioningState"

# View application logs
az containerapp logs show --name $CONTAINER_APP_NAME --resource-group <your-resource-group-name> --follow

# Check if the app is healthy
curl -I https://$FQDN
```

## 🔧 Troubleshooting

### Local Docker Issues

```bash
# Check container status
docker ps -a

# View detailed logs
docker logs blazor-chat-container -f

# Inspect container
docker inspect blazor-chat-container

# Test container connectivity
curl -I http://localhost:8080
```

### Azure Container Apps Issues

```bash
# Check container app revision status
az containerapp revision list --name $CONTAINER_APP_NAME --resource-group <your-resource-group-name> --output table

# View environment details
az containerapp env list --resource-group <your-resource-group-name> --output table

# Check if image exists in ACR
az acr repository show-tags --name $ACR_NAME --repository blazor-cosmos-chat
```

## 📝 Configuration Notes

- The app uses both API key and Managed Identity authentication for Azure services
- **Cosmos DB connection requires Managed Identity**: The app uses DefaultAzureCredential for secure authentication to Cosmos DB. Ensure the container app's managed identity has the "Cosmos DB Built-in Data Contributor" role assigned
- **Database and Container Names**: The app connects to database `vectordb` and container `Container3` in Cosmos DB. Ensure these exist with vector search enabled
- Vector embeddings are generated using `text-embedding-ada-002` model
- Chat completion uses the configured GPT model (default: `gpt-35-turbo`)
- **Security Best Practice**: Using Managed Identity eliminates the need to store Cosmos DB connection strings or keys in your application configuration
