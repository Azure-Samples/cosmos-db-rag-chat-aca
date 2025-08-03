#!/bin/bash

# Azure Cosmos DB Vector Data Seeder
# Seeds vector sample data from local seed-data.json into Azure Cosmos DB after deployment

set -e  # Exit on any error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    printf "${1}${2}${NC}\n"
}

# Function to check if Azure CLI is logged in
check_azure_login() {
    if az account show &>/dev/null; then
        local account_name=$(az account show --query "user.name" -o tsv 2>/dev/null)
        print_color "$GREEN" "✅ Logged in to Azure as: $account_name"
        return 0
    else
        print_color "$RED" "❌ Not logged in to Azure. Please run 'az login' first."
        return 1
    fi
}

# Function to get Cosmos endpoint from azd environment
get_cosmos_endpoint_from_azd() {
    print_color "$BLUE" "🔍 Getting Cosmos DB endpoint from azd environment..."
    
    if command -v azd &> /dev/null; then
        local endpoint=$(azd env get-values 2>/dev/null | grep -i "COSMOS.*ENDPOINT" | head -1 | cut -d'=' -f2 | tr -d '"' || echo "")
        if [[ -n "$endpoint" && "$endpoint" == *"documents.azure.com"* ]]; then
            echo "$endpoint"
            return 0
        fi
    fi
    
    print_color "$YELLOW" "⚠️  Could not retrieve Cosmos endpoint from azd environment"
    return 1
}

# Function to build and run data seeder
run_data_seeder() {
    local endpoint="$1"
    
    print_color "$BLUE" "📦 Building data seeder..."
    
    local seeder_path="$(dirname "$0")/Tools/DataSeeder"
    if [[ ! -d "$seeder_path" ]]; then
        print_color "$RED" "❌ DataSeeder project not found at: $seeder_path"
        return 1
    fi
    
    pushd "$seeder_path" > /dev/null
    
    # Build the project
    if ! dotnet build --configuration Release; then
        print_color "$RED" "❌ Failed to build DataSeeder project"
        popd > /dev/null
        return 1
    fi
    
    # Set environment variable for Cosmos endpoint
    export COSMOS_DB__ENDPOINT_DB="$endpoint"
    
    print_color "$BLUE" "🚀 Running data seeder..."
    
    if dotnet run --configuration Release; then
        print_color "$GREEN" "✅ Data seeding completed successfully!"
        popd > /dev/null
        return 0
    else
        print_color "$RED" "❌ Data seeding failed"
        popd > /dev/null
        return 1
    fi
}

# Main script execution
main() {
    print_color "$BLUE" "=== Azure Cosmos DB Vector Data Seeder ==="
    print_color "$YELLOW" "This script will seed your Cosmos DB with sample vector data for testing RAG functionality.\n"
    
    # Check if dotnet is installed
    if ! command -v dotnet &> /dev/null; then
        print_color "$RED" "❌ .NET SDK is not installed. Please install .NET 9.0 SDK and try again."
        exit 1
    fi
    
    # Check Azure login
    if ! check_azure_login; then
        print_color "$YELLOW" "Please run 'az login' and try again."
        exit 1
    fi
    
    # Get Cosmos endpoint
    local cosmos_endpoint="$1"
    if [[ -z "$cosmos_endpoint" ]]; then
        cosmos_endpoint=$(get_cosmos_endpoint_from_azd) || true
    fi
    
    if [[ -z "$cosmos_endpoint" ]]; then
        print_color "$RED" "❌ Could not determine Cosmos DB endpoint."
        print_color "$YELLOW" "Please provide it as an argument:"
        echo "Usage: $0 <cosmos-endpoint>"
        echo "Example: $0 https://mycosmosdb.documents.azure.com:443/"
        exit 1
    fi
    
    print_color "$GREEN" "📍 Cosmos DB Endpoint: $cosmos_endpoint"
    
    # Confirmation
    if [[ "${FORCE:-}" != "true" ]]; then
        print_color "$YELLOW" "\n⚠️  This will download sample vector data and upload it to your Cosmos DB container."
        print_color "$YELLOW" "   Database: vectordb"
        print_color "$YELLOW" "   Container: Container3"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_color "$YELLOW" "Operation cancelled."
            exit 0
        fi
    fi
    
    # Run the seeding
    if run_data_seeder "$cosmos_endpoint"; then
        print_color "$GREEN" "\n🎉 Success! Your Cosmos DB now contains sample vector data."
        print_color "$GREEN" "You can now test the RAG functionality in your Blazor chat application."
        print_color "$BLUE" "\nTry asking questions like:"
        print_color "$BLUE" "  • 'What is Azure Functions?'"
        print_color "$BLUE" "  • 'Tell me about Azure Cosmos DB'"
        print_color "$BLUE" "  • 'How does Azure Storage work?'"
    else
        print_color "$RED" "\n❌ Data seeding failed. Please check the error messages above."
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
