# Blazor Cosmos Vector Search - RAG Chat Application

A **Retrieval-Augmented Generation (RAG)** chat application built with **Blazor Server**, **Azure Cosmos DB** vector search, and **Azure OpenAI**. This application demonstrates modern AI-powered chat experiences using hybrid search capabilities.

## ✨ Features

- **AI-Powered Chat**: Integration with Azure OpenAI for intelligent responses
- **Vector Search**: Azure Cosmos DB vector search with pre-computed embeddings
- **Secure Authentication**: Azure Managed Identity for secure service connections
- **Containerized**: Docker support for easy deployment and scaling
- **Infrastructure as Code**: Bicep templates for complete Azure resource provisioning
- **Responsive UI**: Modern Blazor Server interface with real-time updates
- **Sample Data**: Includes 108 pre-loaded technology articles with embeddings

## 🏗️ Architecture

`	ext
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Blazor App    │───▶│  Azure OpenAI    │    │  Azure Cosmos   │
│  (Container)    │    │   GPT-4o         │    │      DB         │
└─────────────────┘    └──────────────────┘    │  Vector Search  │
         │                                      └─────────────────┘
         │                                              ▲
         │              ┌──────────────────┐            │
         └─────────────▶│ Direct OpenAI    │────────────┘
                        │   Client         │
                        └──────────────────┘
`

## 🛠️ Technology Stack

- **Frontend**: Blazor Server (.NET 9.0)
- **AI/ML**: Azure OpenAI (direct client)
- **Database**: Azure Cosmos DB (with vector search)
- **Authentication**: Azure Managed Identity
- **Containerization**: Docker
- **Infrastructure**: Azure Container Apps, Azure Container Registry
- **IaC**: Bicep templates (modular architecture)

## 🚀 Quick Start with Azure Developer CLI (Recommended)

The fastest way to get this application running in Azure:

### Prerequisites

- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) installed
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) installed
- [Docker Desktop](https://www.docker.com/products/docker-desktop) running
- An Azure subscription with access to:
  - Azure Cosmos DB (with vector search enabled)
  - Azure OpenAI Service
  - Azure Container Apps

### Deploy to Azure

`ash
# Clone the repository
git clone https://github.com/Azure-Samples/cosmos-db-rag-chat-aca.git
cd cosmos-db-rag-chat-aca/BlazorChatApp

# Login to Azure
azd auth login

# Initialize the project (first time only)
azd init

# Deploy infrastructure and application
azd up
`

That's it! The zd up command will:

1. **Provision infrastructure**: Creates all Azure resources using Bicep templates
2. **Build container**: Builds and pushes the Docker image to Azure Container Registry
3. **Deploy application**: Deploys the containerized app to Azure Container Apps
4. **Configure security**: Sets up managed identity and role assignments
5. **Seed sample data**: Loads 108 technology articles with pre-computed embeddings

### Access Your Application

After deployment completes, you'll get the application URL:

`ash
# View deployment outputs and URLs
azd show

# Your application will be available at:
# - Main App: https://your-app-name.region.azurecontainerapps.io
# - Chat Interface: https://your-app-name.region.azurecontainerapps.io/chat
# - Admin/Seed Data: https://your-app-name.region.azurecontainerapps.io/admin/seed-data
`

### 🔐 Important: Data Seeding Authentication

The application uses **Azure AD authentication** for Cosmos DB access. When you first visit the Admin/Seed Data page:

1. **Portal Authentication**: Navigate to your Cosmos DB account in Azure Portal
2. **Open Data Explorer**: Click "Data Explorer" in the left menu
3. **Login with Entra ID**: Click the "Login with Entra ID" button when prompted
4. **Grant Permissions**: Complete the authentication flow

This one-time authentication step enables your user account to access Cosmos DB through the Azure Portal, which is required for initial data seeding operations.

## 🐳 Local Development with Docker

### 1. Configure Application Settings

Create a local ppsettings.Development.json file:

`json
{
  "COSMOS_DB": {
    "ENDPOINT_DB": "https://your-cosmos-db.documents.azure.com:443/"
  },
  "OpenAI": {
    "DEPLOYMENT_NAME": "gpt-4o",
    "ENDPOINT": "https://your-openai.openai.azure.com/",
    "MODEL_ID": "gpt-4o"
  }
}
`

### 2. Build and Run

`ash
# Build the Docker image
docker build -t blazor-chat-app .

# Run the container
docker run -d -p 8080:8080 --name blazor-chat-container blazor-chat-app

# Access the application
# - Main App: http://localhost:8080
# - Chat Interface: http://localhost:8080/chat
`

### 3. Stop and Clean Up

`ash
# Stop and remove container
docker stop blazor-chat-container
docker rm blazor-chat-container

# Remove image (optional)
docker rmi blazor-chat-app
`

## �� Troubleshooting

### Common Issues

**Authentication Error: "Access denied due to invalid subscription key"**

- Solution: This usually means API key authentication is interfering with managed identity
- Ensure ppsettings.json does not contain hardcoded API keys
- The application should use managed identity for Azure OpenAI access

**Cosmos DB Authentication Issues**

- Error: "Authorization header doesn't confirm to the required format"
- Error: "Local Authorization is disabled"
- Solution: Your user account needs Azure AD authentication
  1. Go to Azure Portal → Your Cosmos DB account → Data Explorer
  2. Click "Login with Entra ID" button
  3. Complete authentication flow

**Container App Won't Start**

- Check container app logs: zd show then follow the logs URL
- Verify managed identity permissions are properly configured
- Ensure Docker image was successfully pushed to ACR

**Chat Not Working**

- Verify Azure OpenAI deployment is accessible
- Check that Cosmos DB database ectordb and container Container3 exist
- Confirm sample data has been seeded

### Useful Commands

`ash
# View application status and URLs
azd show

# Check deployment logs
azd monitor --logs

# Update only the application (skip infrastructure)
azd deploy

# Clean up all resources
azd down

# View environment variables
azd env get-values

# Open Azure portal for current resources
azd monitor --overview
`

### Monitor Your Application

`ash
# Check container app status directly
az containerapp show --name <app-name> --resource-group <rg-name> --query "properties.provisioningState"

# View live application logs
az containerapp logs show --name <app-name> --resource-group <rg-name> --follow

# Test application health
curl -I https://your-app-url
`

## 📁 Project Structure

`
cosmos-db-rag-chat-aca/
├── BlazorChatApp/              # Main application directory
│   ├── Components/
│   │   ├── Layout/             # App layout components
│   │   └── Pages/              # Blazor pages (Home, Chat, SeedData, Error)
│   ├── Utils/                  # DataSeeder utility class
│   ├── infra/                  # Bicep infrastructure templates
│   │   ├── main.bicep          # Main infrastructure template
│   │   └── modules/            # Modular Bicep templates
│   ├── wwwroot/                # Static web assets
│   ├── seed-data.json          # 108 sample documents with embeddings
│   ├── azure.yaml              # AZD configuration
│   ├── Dockerfile              # Container configuration
│   └── README.md               # Application documentation
├── .github/                    # GitHub workflows and templates
├── azure.yaml                  # Root AZD configuration
└── README.md                   # This file
`

## 📖 How It Works

### RAG (Retrieval-Augmented Generation) Flow

1. **User Query**: User submits a question through the chat interface
2. **Vector Search**: Application converts query to embeddings and searches Cosmos DB
3. **Context Retrieval**: Relevant documents are retrieved using vector similarity
4. **Augmented Prompt**: Retrieved context is combined with user query
5. **AI Response**: Azure OpenAI generates response based on augmented prompt

### Data Structure

The application uses the following data structure in Cosmos DB:

`json
{
  "id": "doc-001",
  "title": "Document Title",
  "content": "Document content...",
  "category": "Technology",
  "titleVector": [0.1, 0.2, ...],
  "contentVector": [0.3, 0.4, ...],
  "partitionKey": "Technology"
}
`

### Security Model

- **Managed Identity**: Container app authenticates to Azure services without storing credentials
- **Azure AD Authentication**: User accounts require Azure AD authentication for admin operations
- **Role-Based Access**: Specific roles assigned for Cosmos DB and Azure OpenAI access
- **No Hardcoded Secrets**: All authentication handled through Azure identity services

## 🤝 Contributing

This is an Azure Sample. Contributions are welcome! Please feel free to submit issues and pull requests.

## 📚 Additional Resources

- [Azure Cosmos DB Vector Search Documentation](https://docs.microsoft.com/azure/cosmos-db/vector-search)
- [Azure OpenAI Service Documentation](https://docs.microsoft.com/azure/cognitive-services/openai/)
- [Azure Container Apps Documentation](https://docs.microsoft.com/azure/container-apps/)
- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
