#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Seeds vector sample data into Azure Cosmos DB after deployment

.DESCRIPTION
    This script loads sample vector data from the local seed-data.json file and uploads it
    to your Cosmos DB container. Run this after successfully deploying your application
    with 'azd up' to populate the database with test data.

.PARAMETER CosmosEndpoint
    The Cosmos DB endpoint URL. If not provided, will attempt to get from azd environment.

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\seed-cosmos-data.ps1
    
.EXAMPLE
    .\seed-cosmos-data.ps1 -CosmosEndpoint "https://mycosmosdb.documents.azure.com:443/" -Force
#>

param(
    [string]$CosmosEndpoint,
    [switch]$Force
)

# Colors for output
$Green = "`e[32m"
$Yellow = "`e[33m"
$Red = "`e[31m"
$Blue = "`e[34m"
$Reset = "`e[0m"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = $Reset)
    Write-Host "$Color$Message$Reset"
}

function Get-CosmosEndpointFromAzd {
    try {
        Write-ColorOutput "🔍 Getting Cosmos DB endpoint from azd environment..." $Blue
        $azdEnvValues = azd env get-values --output json | ConvertFrom-Json
        
        if ($azdEnvValues.AZURE_COSMOS_DB_ENDPOINT) {
            return $azdEnvValues.AZURE_COSMOS_DB_ENDPOINT
        }
        
        # Try alternative names
        foreach ($prop in $azdEnvValues.PSObject.Properties) {
            if ($prop.Name -match "COSMOS.*ENDPOINT" -and $prop.Value -match "documents\.azure\.com") {
                return $prop.Value
            }
        }
        
        return $null
    }
    catch {
        Write-ColorOutput "⚠️  Could not retrieve from azd environment: $($_.Exception.Message)" $Yellow
        return $null
    }
}

function Test-AzureLogin {
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        if ($account) {
            Write-ColorOutput "✅ Logged in to Azure as: $($account.user.name)" $Green
            return $true
        }
    }
    catch {
        # Silent catch
    }
    
    Write-ColorOutput "❌ Not logged in to Azure. Please run 'az login' first." $Red
    return $false
}

function Invoke-DataSeeding {
    param([string]$Endpoint)
    
    Write-ColorOutput "📦 Building data seeder..." $Blue
    
    $seederPath = Join-Path $PSScriptRoot "Tools\DataSeeder"
    if (-not (Test-Path $seederPath)) {
        Write-ColorOutput "❌ DataSeeder project not found at: $seederPath" $Red
        return $false
    }
    
    Push-Location $seederPath
    try {
        # Build the project
        dotnet build --configuration Release
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "❌ Failed to build DataSeeder project" $Red
            return $false
        }
        
        # Set environment variable for Cosmos endpoint
        $env:COSMOS_DB__ENDPOINT_DB = $Endpoint
        
        Write-ColorOutput "🚀 Running data seeder..." $Blue
        dotnet run --configuration Release
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Data seeding completed successfully!" $Green
            return $true
        } else {
            Write-ColorOutput "❌ Data seeding failed" $Red
            return $false
        }
    }
    finally {
        Pop-Location
    }
}

# Main script execution
Write-ColorOutput "=== Azure Cosmos DB Vector Data Seeder ===" $Blue
Write-ColorOutput "This script will seed your Cosmos DB with sample vector data for testing RAG functionality.`n" $Yellow

# Check Azure login
if (-not (Test-AzureLogin)) {
    Write-ColorOutput "Please run 'az login' and try again." $Yellow
    exit 1
}

# Get Cosmos endpoint
if (-not $CosmosEndpoint) {
    $CosmosEndpoint = Get-CosmosEndpointFromAzd
}

if (-not $CosmosEndpoint) {
    Write-ColorOutput "❌ Could not determine Cosmos DB endpoint." $Red
    Write-ColorOutput "Please provide it manually:" $Yellow
    $CosmosEndpoint = Read-Host "Enter Cosmos DB endpoint (e.g., https://mycosmosdb.documents.azure.com:443/)"
    
    if (-not $CosmosEndpoint) {
        Write-ColorOutput "❌ Cosmos DB endpoint is required" $Red
        exit 1
    }
}

Write-ColorOutput "📍 Cosmos DB Endpoint: $CosmosEndpoint" $Green

# Confirmation
if (-not $Force) {
    Write-ColorOutput "`n⚠️  This will download sample vector data and upload it to your Cosmos DB container." $Yellow
    Write-ColorOutput "   Database: vectordb" $Yellow
    Write-ColorOutput "   Container: Container3" $Yellow
    $confirm = Read-Host "`nContinue? (y/N)"
    
    if ($confirm -notmatch '^[yY]') {
        Write-ColorOutput "Operation cancelled." $Yellow
        exit 0
    }
}

# Run the seeding
$success = Invoke-DataSeeding -Endpoint $CosmosEndpoint

if ($success) {
    Write-ColorOutput "`n🎉 Success! Your Cosmos DB now contains sample vector data." $Green
    Write-ColorOutput "You can now test the RAG functionality in your Blazor chat application." $Green
    Write-ColorOutput "`nTry asking questions like:" $Blue
    Write-ColorOutput "  • 'What is Azure Functions?'" $Blue
    Write-ColorOutput "  • 'Tell me about Azure Cosmos DB'" $Blue
    Write-ColorOutput "  • 'How does Azure Storage work?'" $Blue
} else {
    Write-ColorOutput "`n❌ Data seeding failed. Please check the error messages above." $Red
    exit 1
}
