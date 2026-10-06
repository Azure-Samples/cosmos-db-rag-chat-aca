# Blazor Cosmos Vector Search - RAG Chat Application

A **Retrieval-Augmented Generation (RAG)** chat application built with **Blazor Server**, **Azure Cosmos DB** vector search, and **Azure OpenAI**. This application demonstrates modern AI-powered chat experiences using hybrid search capabilities.

## 🏗️ Architecture

```text
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Blazor App    │───▶│  Azure OpenAI    |    │  Azure Cosmos   │
│  (Container)    │    │   GPT-5.1        │    │      DB         │
└─────────────────┘    └──────────────────┘    │  Vector Search  │
         │                                      └─────────────────┘
         │                                              ▲
         │              ┌──────────────────┐            │
         └─────────────▶│ Direct OpenAI    │────────────┘
                        │   Client         │
                        └──────────────────┘
```

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

```bash
# Clone the repository
git clone https://github.com/Azure-Samples/cosmos-db-rag-chat-aca.git
cd cosmos-db-rag-chat-aca/BlazorChatApp

# Login to Azure
azd auth login

# Initialize the project (first time only)
azd init

# Deploy infrastructure and application
azd up
```

That's it! The `azd up` command will:

1. 🏗️ **Provision infrastructure**: Creates all Azure resources using Bicep templates
2. 🐳 **Build container**: Builds and pushes the Docker image to Azure Container Registry
3. 🚀 **Deploy application**: Deploys the containerized app to Azure Container Apps
4. 🔧 **Configure security**: Sets up managed identity and role assignments
5. 📊 **Seed sample data**: Loads 108 technology articles with pre-computed embeddings

### Access Your Application

After deployment completes, you'll get the application URL:

```bash
# View deployment outputs and URLs
azd show

# Your application will be available at:
# - Main App: https://your-app-name.region.azurecontainerapps.io
# - Chat Interface: https://your-app-name.region.azurecontainerapps.io/chat
# - Admin/Seed Data: https://your-app-name.region.azurecontainerapps.io/admin/seed-data
```

### 🔐 Important: Data Seeding Authentication

The Seed Data navigation link is always visible, while the page itself requires Microsoft Entra ID sign-in. Configure the app registration used by `AzureAd:ClientId` with:

1. **Redirect URI**: `https://<your-app-hostname>/signin-oidc`
2. **Implicit ID tokens**: Enable ID token issuance for this sign-in-only sample
3. **Configuration values**: `AzureAd:TenantId` and `AzureAd:ClientId`

Cosmos DB writes run under the container app managed identity; user credentials are not sent to Cosmos DB.

## 🐳 Local Development with Docker

### 1. Configure Application Settings

Create a local `appsettings.Development.json` file:

```json
{
  "COSMOS_DB": {
    "ENDPOINT_DB": "https://your-cosmos-db.documents.azure.com:443/"
  },
  "OpenAI": {
    "DEPLOYMENT_NAME": "gpt-5.1",
    "ENDPOINT": "https://your-openai.openai.azure.com/",
    "MODEL_ID": "gpt-5.1"
  }
}
```

### 2. Build and Run

```bash
# Build the Docker image
docker build -t blazor-chat-app .

# Run the container
docker run -d -p 8080:8080 --name blazor-chat-container blazor-chat-app

# Access the application
# - Main App: http://localhost:8080
# - Chat Interface: http://localhost:8080/chat
```

### 3. Stop and Clean Up

```bash
# Stop and remove container
docker stop blazor-chat-container
docker rm blazor-chat-container

# Remove image (optional)
docker rmi blazor-chat-app
```

## 🔧 Troubleshooting

### Common Issues

#### Authentication Error: "Access denied due to invalid subscription key"

- Solution: This usually means API key authentication is interfering with managed identity
- Ensure `appsettings.json` does not contain hardcoded API keys
- The application should use managed identity for Azure OpenAI access

#### Cosmos DB Authentication and Data Issues

The current deployment uses:

- Cosmos DB account: the generated `blazorchat-cosmos-*` account
- Database: `ChatRagDb`
- RAG document container: `KnowledgeDocuments`
- Reserved conversation container: `ChatMessages`

The older `vectordb` database and `Container3` container might still exist after an upgrade, but the application no longer uses them.

**Data Explorer reports `readMetadata` is blocked**

The principal shown in the error needs a Cosmos DB native data-plane role on the Cosmos DB account. Assign **Cosmos DB Built-in Data Contributor** at the account scope, wait several minutes for propagation, and then refresh the Entra token or sign in again. Azure resource-management roles such as Contributor do not grant Cosmos DB document access.

**The application reports local authorization or authorization-header errors**

Local key authentication is disabled. The deployed Container App accesses Cosmos DB through its managed identity, which must have **Cosmos DB Built-in Data Contributor** at the account scope. Data Explorer uses the signed-in user's identity instead, so the user and the Container App identity can require separate assignments.

**The Seed Data page is missing or fails during sign-in**

- The **Seed Data** navigation link should always be visible at `/admin/seed-data`.
- The page requires Microsoft Entra ID sign-in.
- Confirm the app registration redirect URI exactly matches `https://<your-app-hostname>/signin-oidc`.
- Confirm ID token issuance is enabled and the azd environment values `AZURE_AD_TENANT_ID` and `AZURE_AD_CLIENT_ID` identify that app registration.

**`KnowledgeDocuments` contains no items**

Newly provisioned containers start empty. Sign in, open **Seed Data**, and run **Start Data Seeding** to load the bundled documents. Chat requests only read from `KnowledgeDocuments`; they do not create documents. `ChatMessages` is provisioned for future conversation persistence but is not currently written by the application.

**Cosmos DB returns an `ORDER BY`, `RRF`, or apostrophe syntax error**

The running Container App is likely using an older image with the previous hybrid-search query. Redeploy the web service so it uses the parameterized vector query:

```bash
azd deploy web
```

#### Container App Won't Start

- Check container app logs: `azd show` then follow the logs URL
- Verify managed identity permissions are properly configured
- Ensure Docker image was successfully pushed to ACR

#### Chat Not Working

- Verify Azure OpenAI deployment is accessible
- Check that Cosmos DB database `ChatRagDb` and container `KnowledgeDocuments` exist
- Confirm `KnowledgeDocuments` contains seeded items
- Confirm the Container App managed identity has Cosmos DB Built-in Data Contributor at the account scope
- Redeploy the web service if errors reference `Container3`, `RRF`, or interpolated user text

### Useful Commands

```bash
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
```

### Monitor Your Application

```bash
# Check container app status directly
az containerapp show --name <app-name> --resource-group <rg-name> --query "properties.provisioningState"

# View live application logs
az containerapp logs show --name <app-name> --resource-group <rg-name> --follow

# Test application health
curl -I https://your-app-url
```

## 📁 Project Structure

```
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
```

## 📖 How It Works

### RAG (Retrieval-Augmented Generation) Flow

1. **User Query**: User submits a question through the chat interface
2. **Vector Search**: Application converts query to embeddings and searches Cosmos DB
3. **Context Retrieval**: Relevant documents are retrieved using vector similarity
4. **Augmented Prompt**: Retrieved context is combined with user query
5. **AI Response**: Azure OpenAI generates response based on augmented prompt
6. **Real-time Response**: Answer is displayed with typing indicators for better UX

### Data Structure

The application uses the following data structure in Cosmos DB:

```json
{
  "id": "doc-001",
  "title": "Document Title",
  "content": "Document content...",
  "category": "Technology",
  "titleVector": [0.1, 0.2, ...],
  "contentVector": [0.3, 0.4, ...],
  "partitionKey": "Technology"
}
```

### Security Model

- **Managed Identity**: Container app authenticates to Azure services without storing credentials
- **Entra ID Authentication**: User accounts require Microsoft Entra ID sign-in for admin operations
- **Authenticated Data Seeding**: `/admin/seed-data` requires Microsoft Entra ID sign-in before Cosmos DB writes can start
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
