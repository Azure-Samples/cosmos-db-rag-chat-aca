# Blazor Cosmos Vector Search - RAG Chat Application

A **Retrieval-Augmented Generation (RAG)** chat application built with **Blazor Server**, **Azure Cosmos DB** vector search, and **Azure OpenAI**. This application demonstrates modern AI-powered chat experiences using hybrid search with Reciprocal Rank Fusion (RRF) for enhanced search accuracy.

## Features

- **AI-Powered Chat**: Integration with Azure OpenAI for intelligent responses
- **Vector Search**: Azure Cosmos DB vector search with hybrid search capabilities  
- **Real-time Streaming**: Streaming chat responses for better user experience
- **Secure Authentication**: Azure Managed Identity for secure service connections
- **Containerized**: Docker support for easy deployment and scaling
- **Infrastructure as Code**: Bicep templates for complete Azure resource provisioning
- **Responsive UI**: Modern Blazor Server interface with real-time updates

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Blazor App    │───▶│  Azure OpenAI    │    │  Azure Cosmos   │
│  (Container)    │    │   GPT-4o         │    │      DB         │
└─────────────────┘    └──────────────────┘    │  Vector Search  │
         │                                      └─────────────────┘
         │                                              ▲
         │              ┌──────────────────┐            │
         └─────────────▶│ Semantic Kernel  │────────────┘
                        │   Embeddings     │
                        └──────────────────┘
```

## Technology Stack

- **Frontend**: Blazor Server (.NET 9.0)
- **AI/ML**: Azure OpenAI, Semantic Kernel
- **Database**: Azure Cosmos DB (with vector search)
- **Authentication**: Azure Managed Identity
- **Containerization**: Docker
- **Infrastructure**: Azure Container Apps, Azure Container Registry
- **IaC**: Bicep templates (modular architecture)

## 🚀 Quick Deploy with Azure Developer CLI (azd)

**Get this app running in Azure in under 5 minutes:**

```bash
# Clone the repository
git clone https://github.com/Azure-Samples/cosmos-db-rag-chat-aca.git
cd cosmos-db-rag-chat-aca

# Install Azure Developer CLI (if not already installed)
# Windows: winget install Microsoft.Azd
# macOS: brew install azure-developer-cli
# Linux: curl -fsSL https://aka.ms/install-azd.sh | bash

# Deploy everything with one command
azd auth login
azd up
```

**What gets deployed:**
- ✅ **Azure Cosmos DB** with vector search enabled
- ✅ **Azure OpenAI** with GPT-4o and text-embedding-ada-002 models
- ✅ **Azure Container Apps** with managed identity
- ✅ **Azure Container Registry** for your app
- ✅ **Complete infrastructure** with secure connections

**After deployment:**
- Get your app URL with: `azd show`
- View logs with: `azd logs --follow`
- Update code with: `azd deploy`
- Clean up with: `azd down`

## Prerequisites

- **Docker Desktop** installed and running
- **Azure CLI** installed and logged in
- **Azure subscription** with access to:
  - Azure Cosmos DB (with vector search enabled)
  - Azure OpenAI Service
  - Azure Container Registry
  - Azure Container Apps

## Local Development with Docker

### 1. Configure Application Settings

Update `BlazorChatApp/appsettings.json` with your Azure service configurations:

```json
{
  "COSMOS_DB": {
    "ENDPOINT_DB": "https://your-cosmos-db.documents.azure.com:443/"
  },
  "OpenAI": {
    "DEPLOYMENT_NAME": "gpt-4o",
    "ENDPOINT": "https://your-openai.openai.azure.com/",
    "API_KEY": "your-api-key",
    "MODEL_ID": "gpt-4o"
  }
}
```

### 2. Build and Run Docker Container

```bash
# Build the Docker image
docker build -t blazor-chat-app .

# Run the container
docker run -d -p 8080:8080 --name blazor-chat-container blazor-chat-app

# Check if container is running
docker ps
```

### 3. Access the Application

- **Main Application**: <http://localhost:8080>
- **Chat Interface**: <http://localhost:8080/chat>

### 4. Stop and Clean Up

```bash
# Stop and remove container
docker stop blazor-chat-container
docker rm blazor-chat-container

# Remove image (optional)
docker rmi blazor-chat-app
```

## Azure Deployment with Azure Developer CLI (azd)

### Prerequisites for azd

- **Azure Developer CLI (azd)** installed ([Installation Guide](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd))
- **Azure CLI** installed and logged in
- **Docker Desktop** running (for container image building)

### Option 1: Quick Deployment with azd (Recommended)

This is the fastest way to deploy the complete application with all Azure resources:

```bash
# 1. Navigate to the project directory
cd BlazorChatApp

# 2. Initialize azd (first time only)
azd auth login
azd init

# 3. Deploy everything (infrastructure + application)
azd up
```

The `azd up` command will:

- ✅ Provision all Azure resources (Cosmos DB, OpenAI, Container Apps, etc.)
- ✅ Build and containerize your application
- ✅ Deploy the container to Azure Container Apps
- ✅ Configure all environment variables and connections
- ✅ Set up managed identity authentication

### Option 2: Step-by-Step azd Deployment

For more control over the deployment process:

```bash
# 1. Login to Azure
azd auth login

# 2. Initialize the project (creates .azure directory)
azd init

# 3. Provision Azure infrastructure only
azd provision

# 4. Build and deploy application only  
azd deploy

# 5. View deployment status and get app URL
azd show

# 6. View environment variables and outputs
azd env get-values
```

**Key azd commands:**

```bash
# Create and switch environments (dev, staging, prod)
azd env new <environment-name>
azd env select <environment-name>
azd env list

# Monitor your application
azd logs --follow
azd monitor --overview

# Update deployments
azd deploy              # Deploy code changes only
azd provision          # Update infrastructure only
azd up                 # Deploy everything

# Clean up resources
azd down --purge       # Delete all resources
```

## Manual Azure Container Apps Deployment

If you prefer manual deployment or need more customization:

### 1. Deploy Infrastructure

```bash
# Deploy Azure resources using Bicep
az deployment group create \
  --resource-group <your-resource-group-name> \
  --template-file infra/main.bicep \
  --parameters environmentName=dev location=eastus
```

### 2. Build and Push Application Image

```bash
# Get deployment outputs
ACR_NAME=$(az deployment group show --resource-group <your-resource-group-name> --name main --query properties.outputs.acrName.value -o tsv)
ACR_LOGIN_SERVER=$(az deployment group show --resource-group <your-resource-group-name> --name main --query properties.outputs.acrLoginServer.value -o tsv)

# Login to Azure Container Registry
az acr login --name $ACR_NAME

# Build and push image
docker build -t $ACR_LOGIN_SERVER/blazor-cosmos-chat:latest .
docker push $ACR_LOGIN_SERVER/blazor-cosmos-chat:latest
```

### 3. Update Container App

```bash
# Get container app name
CONTAINER_APP_NAME=$(az deployment group show --resource-group <your-resource-group-name> --name main --query properties.outputs.containerAppName.value -o tsv)

# Update container app with your image
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group <your-resource-group-name> \
  --image $ACR_LOGIN_SERVER/blazor-cosmos-chat:latest
```

### 4. Get Application URL

```bash
# Get the application URL
FQDN=$(az deployment group show --resource-group <your-resource-group-name> --name main --query properties.outputs.containerAppFqdn.value -o tsv)
echo "Your application is available at: https://$FQDN"
echo "Chat interface: https://$FQDN/chat"
```

## Project Structure

```
BlazorChatApp/
├── Components/
│   ├── Layout/              # Layout components
│   ├── Pages/
│   │   ├── Chat.razor       # Main chat interface with RAG implementation
│   │   └── ...
│   └── _Imports.razor       # Global using statements
├── infra/                   # Infrastructure as Code
│   ├── main.bicep          # Main Bicep template
│   ├── main.parameters.json # Deployment parameters
│   └── modules/
│       ├── container-app.bicep    # Container Apps configuration
│       ├── cosmos-db.bicep        # Cosmos DB setup
│       └── openai.bicep           # Azure OpenAI configuration
├── azure.yaml              # Azure Developer CLI configuration
├── Dockerfile              # Multi-stage Docker build
├── appsettings.json        # Application configuration
└── README.md               # This file
```

## Azure Developer CLI Configuration

This project includes `azure.yaml` which configures azd for seamless deployment:

```yaml
# azure.yaml
name: blazor-cosmos-chat
services:
  web:
    project: .
    language: dotnet
    host: containerapp
    docker:
      path: ./Dockerfile
infra:
  provider: bicep
  path: infra
```

### Key azd Features Enabled

- **Infrastructure as Code**: Uses Bicep templates in `/infra` folder
- **Container Building**: Automatically builds Docker images
- **Service Deployment**: Deploys to Azure Container Apps
- **Environment Management**: Supports multiple environments (dev, staging, prod)
- **Managed Identity**: Automatically configures secure service connections

### Customizing Deployment

You can customize the deployment by modifying `infra/main.parameters.json`:

```json
{
  "parameters": {
    "location": {
      "value": "eastus"
    },
    "environmentName": {
      "value": "dev"
    }
  }
}
```

## Configuration

### Required Azure Services

1. **Azure Cosmos DB**
   - Database: `ChatDatabase`
   - Container: `ChatMessages`
   - Vector search enabled
   - Indexing policy configured for vector fields

2. **Azure OpenAI**
   - **Chat Model**: GPT-4o deployment (name: `gpt-4o`)
   - **Embedding Model**: text-embedding-ada-002 deployment (name: `text-embedding-ada-002`)
   - Both models are automatically deployed with standard SKU

3. **Azure Container Apps Environment**
   - Container registry integration
   - Managed identity enabled

### Environment Variables

The application uses these configuration sections:

- `COSMOS_DB:ENDPOINT_DB` - Cosmos DB endpoint URL
- `OpenAI:DEPLOYMENT_NAME` - Azure OpenAI deployment name
- `OpenAI:ENDPOINT` - Azure OpenAI endpoint URL
- `OpenAI:API_KEY` - Azure OpenAI API key (for local development)
- `OpenAI:MODEL_ID` - Model identifier

## Security Best Practices

- **Managed Identity**: Used for secure authentication to Azure services
- **No hardcoded secrets**: API keys only used for local development
- **Role-based access**: Cosmos DB access via built-in data contributor role
- **Container security**: Multi-stage Docker builds for optimized images

## How It Works

1. **User Input**: User submits a question through the chat interface
2. **Embedding Generation**: Question is converted to vector embedding using Azure OpenAI
3. **Hybrid Search**: Cosmos DB performs vector similarity search + full-text search using RRF
4. **Context Retrieval**: Relevant documents are retrieved and used as context
5. **AI Response**: Azure OpenAI generates response using retrieved context
6. **Streaming**: Response is streamed back to user in real-time

## Troubleshooting

### azd (Azure Developer CLI) Issues

**First time setup:**

```bash
# Install azd if not already installed
winget install Microsoft.Azd  # Windows
# or
brew install azure-developer-cli  # macOS
# or  
curl -fsSL https://aka.ms/install-azd.sh | bash  # Linux

# Verify installation
azd version

# Login to Azure
azd auth login

# Check you have the right subscription
az account show
```

**azd up fails during provisioning:**

```bash
# View detailed logs
azd provision --debug

# Check current environment
azd env get-values

# Verify Azure CLI login
az account show

# Check resource quotas in target region
az vm list-usage --location eastus
```

**Service tag conflict (service already exists):**

This can happen if you're redeploying to the same environment. The solution is to use a different environment:

```bash
# Create a new environment
azd env new prod  # or any other name

# Select the new environment
azd env select prod

# Deploy to the new environment
azd up
```

**OpenAI service unavailable in region:**

```bash
# Check which regions have OpenAI service available
# Recommended regions: eastus, eastus2, westus2, northcentral

# Set a different region for your deployment
azd env set AZURE_LOCATION eastus2
azd up

# Or if already deployed, you may need to start fresh:
azd down --purge
azd env set AZURE_LOCATION eastus2
azd up
```

**azd deploy fails:**

```bash
# View deployment logs
azd deploy --debug

# Check container app status
azd show

# Rebuild and redeploy
azd package
azd deploy
```

**Environment management issues:**

```bash
# List all environments
azd env list

# Reset current environment
azd down
azd up

# Create fresh environment
azd env new <new-env-name>
azd env select <new-env-name>
azd up
```

### Common Issues

**Container App won't start:**

- Check if the container image exists in ACR
- Verify managed identity permissions for Cosmos DB
- Review container app logs: `azd show` then check the provided URL

**Chat not working:**

- Ensure Cosmos DB connection is configured
- Verify Azure OpenAI deployment is accessible  
- Check that database `ChatDatabase` and container `ChatMessages` exist

**Local Docker issues:**

- Verify Docker Desktop is running
- Check port 8080 is not in use
- Review container logs: `docker logs blazor-chat-container`

### Monitor Deployment

#### Using azd commands

```bash
# Get application URL and status
azd show

# View environment variables
azd env get-values

# Check deployment logs
azd show --output json
```

#### Using Azure CLI

```bash
# Check container app status
az containerapp show --name $CONTAINER_APP_NAME --resource-group <your-resource-group-name> --query "properties.provisioningState"

# View application logs
az containerapp logs show --name $CONTAINER_APP_NAME --resource-group <your-resource-group-name> --follow

# Check if the app is healthy
curl -I https://$FQDN
```

### Useful azd Commands

```bash
# Get help for any azd command
azd <command> --help

# View current project status
azd show

# Get deployment outputs (URLs, connection strings, etc.)
azd env get-values

# Key outputs you'll see:
# - WEBSITE_URL: Your application's public URL
# - AZURE_COSMOS_DB_ENDPOINT: Cosmos DB endpoint
# - AZURE_OPENAI_ENDPOINT: OpenAI service endpoint
# - AZURE_OPENAI_CHAT_DEPLOYMENT_NAME: Chat model deployment name (gpt-4o)
# - AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME: Embedding model name (text-embedding-ada-002)

# Update only the application (skip infrastructure)
azd deploy

# Update only infrastructure
azd provision

# Clean up all resources
azd down

# View all logs
azd monitor --logs

# Open Azure portal for current resources
azd monitor --overview
```

## Additional Resources

- [Azure Cosmos DB Vector Search Documentation](https://docs.microsoft.com/azure/cosmos-db/vector-search)
- [Azure OpenAI Service Documentation](https://docs.microsoft.com/azure/cognitive-services/openai/)
- [Azure Container Apps Documentation](https://docs.microsoft.com/azure/container-apps/)
- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Semantic Kernel Documentation](https://learn.microsoft.com/semantic-kernel/)

## Contributing

This is an Azure Sample. Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
