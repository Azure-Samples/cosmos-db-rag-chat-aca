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
│  (Container)    │    │   GPT-3.5/4      │    │      DB         │
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

## 🚀 Quick Start with Azure Developer CLI

The fastest way to get this application running in Azure:

```bash
# Clone the repository
git clone https://github.com/Azure-Samples/cosmos-db-rag-chat-aca.git
cd cosmos-db-rag-chat-aca/BlazorChatApp

# Install Azure Developer CLI if you haven't already
# Windows: winget install Microsoft.Azd
# macOS: brew install azure-developer-cli
# Linux: curl -fsSL https://aka.ms/install-azd.sh | bash

# Login and deploy everything
azd auth login
azd up
```

That's it! The `azd up` command will:
- ✅ Provision all Azure resources (Cosmos DB, OpenAI with models, Container Apps)
- ✅ Build and deploy your application
- ✅ Configure secure connections with managed identity
- ✅ Provide you with the application URL

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
    "DEPLOYMENT_NAME": "gpt-35-turbo",
    "ENDPOINT": "https://your-openai.openai.azure.com/",
    "API_KEY": "your-api-key",
    "MODEL_ID": "gpt-35-turbo"
  }
}
```

### 2. Build and Run Docker Container

```bash
# Navigate to the BlazorChatApp directory
cd BlazorChatApp

# Build the Docker image
docker build -t blazor-chat-app .

# Run the container
docker run -d -p 8080:8080 --name blazor-chat-container blazor-chat-app

# Check if container is running
docker ps
```

### 3. Access the Application

- **Main Application**: http://localhost:8080
- **Chat Interface**: http://localhost:8080/chat

### 4. Stop and Clean Up

```bash
# Stop and remove container
docker stop blazor-chat-container
docker rm blazor-chat-container

# Remove image (optional)
docker rmi blazor-chat-app
```

## Azure Deployment with Azure Developer CLI (azd)

### Prerequisites

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

# 2. Initialize the project (if not done before)
azd init

# 3. Provision Azure infrastructure only
azd provision

# 4. Build and deploy application only
azd deploy

# 5. View deployment status and get app URL
azd show
```

### Environment Management

```bash
# Create a new environment (e.g., for staging)
azd env new staging

# List all environments
azd env list

# Switch between environments
azd env select <environment-name>

# View current environment variables
azd env get-values
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

# Navigate to app directory and build/push image
cd BlazorChatApp
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

### 4. Configure Managed Identity Access

**Important**: Configure Managed Identity for secure Cosmos DB access:

```bash
# Get the container app's managed identity principal ID
PRINCIPAL_ID=$(az containerapp identity show --name $CONTAINER_APP_NAME --resource-group <your-resource-group-name> --query principalId -o tsv)

# Assign Cosmos DB Built-in Data Contributor role
az cosmosdb sql role assignment create \
  --account-name <your-cosmos-db-account-name> \
  --resource-group <your-resource-group-name> \
  --scope "/" \
  --principal-id $PRINCIPAL_ID \
  --role-definition-id "00000000-0000-0000-0000-000000000002"
```

> **Note**: The role definition ID `00000000-0000-0000-0000-000000000002` corresponds to the "Cosmos DB Built-in Data Contributor" role, which provides read and write access to Cosmos DB data.

### 5. Get Application URL

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
└── deploy-steps.md         # Detailed deployment guide
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
   - Database: `vectordb`
   - Container: `Container3`
   - Vector search enabled
   - Indexing policy configured for vector fields

2. **Azure OpenAI**
   - GPT model deployment (e.g., `gpt-35-turbo`)
   - Text embedding model: `text-embedding-ada-002`

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

#### Using azd commands:

```bash
# Get application URL and status
azd show

# View environment variables
azd env get-values

# Check deployment logs
azd show --output json
```

#### Using Azure CLI:

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

## 🗃️ Seeding Sample Data

After deploying your application, you'll want to populate the Cosmos DB with sample data to test the RAG functionality. We provide sample vector data from Azure Search samples that includes technology articles about various Azure services.

### Option 1: Quick Seeding with PowerShell (Windows)

```powershell
# Run the automated seeding script
.\seed-cosmos-data.ps1

# Or with force flag to skip confirmations  
.\seed-cosmos-data.ps1 -Force

# Or specify Cosmos endpoint manually
.\seed-cosmos-data.ps1 -CosmosEndpoint "https://your-cosmos-db.documents.azure.com:443/"
```

### Option 2: Quick Seeding with Bash (Linux/macOS)

```bash
# Make the script executable
chmod +x seed-cosmos-data.sh

# Run the automated seeding script
./seed-cosmos-data.sh

# Or specify Cosmos endpoint manually
./seed-cosmos-data.sh "https://your-cosmos-db.documents.azure.com:443/"

# Skip confirmation prompts
FORCE=true ./seed-cosmos-data.sh
```

### Option 3: Manual Seeding with .NET Tool

```bash
# Navigate to the data seeder project
cd Tools/DataSeeder

# Set your Cosmos DB endpoint
export COSMOS_DB__ENDPOINT_DB="https://your-cosmos-db.documents.azure.com:443/"
# Or on Windows:
# set COSMOS_DB__ENDPOINT_DB=https://your-cosmos-db.documents.azure.com:443/

# Run the seeder
dotnet run
```

### Option 4: Web-based Seeding

After your application is deployed, you can also use the web interface:

1. Navigate to your deployed application URL
2. Go to the **"Seed Data"** page in the navigation menu
3. Click **"Seed Sample Data"** to populate the database

### What Data Gets Seeded?

The seeding process uses the local [seed-data.json](seed-data.json) file which contains sample vector data from the Azure Search vector samples repository. This includes:

- **Technology Articles**: Content about various Azure services
- **Categories**: Compute, Storage, Databases, Analytics, etc.
- **Vector Embeddings**: Pre-computed embeddings for vector search
- **Rich Content**: Detailed descriptions suitable for RAG scenarios

Sample articles include topics like:

- Azure Functions
- Azure Cosmos DB  
- Azure Storage
- Azure Kubernetes Service
- Azure Data Factory
- And many more...

### Testing After Seeding

Once the data is seeded, you can test the RAG functionality by asking questions like:

- "What is Azure Functions?"
- "How does Azure Cosmos DB work?"
- "Tell me about Azure Storage options"
- "What are the benefits of Azure Kubernetes Service?"

The application will use vector similarity search to find relevant content and generate contextual responses using Azure OpenAI.

### Troubleshooting Data Seeding

**Authentication Issues:**

- Ensure you're logged in to Azure CLI: `az login`
- Verify the container app has Cosmos DB permissions
- Check that managed identity is properly configured

**Connection Issues:**

- Verify the Cosmos DB endpoint is correct
- Ensure the database "vectordb" and container "Container3" exist
- Check that vector search is enabled on your Cosmos DB account

**Data Issues:**

- The seeder will skip documents that already exist
- Check the console output for specific error messages
- Verify your Cosmos DB has sufficient throughput/RU capacity

## Additional Resources

- [Azure Cosmos DB Vector Search Documentation](https://docs.microsoft.com/azure/cosmos-db/vector-search)
- [Azure OpenAI Service Documentation](https://docs.microsoft.com/azure/cognitive-services/openai/)
- [Azure Container Apps Documentation](https://docs.microsoft.com/azure/container-apps/)
- [Semantic Kernel Documentation](https://learn.microsoft.com/semantic-kernel/)

## Contributing

This is an Azure Sample. Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
