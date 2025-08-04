using System.Text.Json;
using Microsoft.Azure.Cosmos;
using Azure.Identity;
using Microsoft.Extensions.Configuration;

namespace BlazorChatApp.Utils;

public class DataSeeder
{
    private readonly IConfiguration _configuration;
    private readonly CosmosClient _cosmosClient;
    
    public DataSeeder(IConfiguration configuration)
    {
        _configuration = configuration;
        
        // Get endpoint from configuration
        var cosmosEndpoint = _configuration["COSMOS_DB:ENDPOINT_DB"] ?? 
                           _configuration["COSMOS_DB__ENDPOINT_DB"];
        
        if (string.IsNullOrEmpty(cosmosEndpoint))
        {
            throw new InvalidOperationException("Cosmos DB endpoint not found in configuration. Expected COSMOS_DB:ENDPOINT_DB or COSMOS_DB__ENDPOINT_DB");
        }
        
        // Use managed identity authentication (AAD token) since local auth is disabled
        var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
        {
            // Exclude problematic credential types for Container Apps
            ExcludeInteractiveBrowserCredential = true,
            ExcludeSharedTokenCacheCredential = true,
            ExcludeVisualStudioCredential = true,
            ExcludeVisualStudioCodeCredential = true,
            ExcludeAzureCliCredential = true,
            ExcludeAzurePowerShellCredential = true,
            // Force to use only managed identity and environment variables
            ExcludeAzureDeveloperCliCredential = true
        });
        
        // Add debug logging for credential source
        Console.WriteLine($"[DEBUG] Cosmos DB endpoint: {cosmosEndpoint}");
        Console.WriteLine($"[DEBUG] Using DefaultAzureCredential with Container Apps optimizations");
        
        _cosmosClient = new CosmosClient(cosmosEndpoint, credential);
    }

    public async Task SeedSampleDataAsync(Action<string>? progressCallback = null)
    {
        try
        {
            progressCallback?.Invoke("🚀 Starting data seeding process...");
            
            // Load sample data from local file
            progressCallback?.Invoke("📁 Loading sample data from local file...");
            var sampleData = await LoadSampleDataAsync();
            progressCallback?.Invoke($"✅ Loaded {sampleData.Count} sample documents from local file");
            
            // Transform to VectorItem format
            progressCallback?.Invoke("🔄 Transforming documents to VectorItem format...");
            var vectorItems = TransformToVectorItems(sampleData);
            progressCallback?.Invoke($"✅ Transformed {vectorItems.Count} documents to VectorItem format");
            
            // Upload to Cosmos DB
            progressCallback?.Invoke("☁️ Starting upload to Cosmos DB...");
            await UploadToCosmosDbAsync(vectorItems, progressCallback);
            progressCallback?.Invoke("🎉 Successfully seeded data to Cosmos DB!");
        }
        catch (Exception ex)
        {
            progressCallback?.Invoke($"❌ Error seeding data: {ex.Message}");
            Console.WriteLine($"Error seeding data: {ex.Message}");
            throw;
        }
    }

    private async Task<List<SampleVectorDocument>> LoadSampleDataAsync()
    {
        var jsonFilePath = Path.Combine(Directory.GetCurrentDirectory(), "seed-data.json");
        
        if (!File.Exists(jsonFilePath))
        {
            throw new FileNotFoundException($"Sample data file not found at: {jsonFilePath}");
        }
        
        var jsonString = await File.ReadAllTextAsync(jsonFilePath);
        
        var documents = JsonSerializer.Deserialize<List<SampleVectorDocument>>(jsonString, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });
        
        return documents ?? new List<SampleVectorDocument>();
    }

    private List<VectorItem> TransformToVectorItems(List<SampleVectorDocument> sampleData)
    {
        var vectorItems = new List<VectorItem>();
        
        foreach (var sample in sampleData)
        {
            var vectorItem = new VectorItem
            {
                id = sample.id,
                title = sample.title,
                content = sample.content,
                category = sample.category,
                titleVector = sample.titleVector?.ToArray() ?? Array.Empty<float>(),
                contentVector = sample.contentVector?.ToArray() ?? Array.Empty<float>(),
                // Add partition key - using category as partition key strategy
                partitionKey = sample.category
            };
            
            vectorItems.Add(vectorItem);
        }
        
        return vectorItems;
    }

    private async Task UploadToCosmosDbAsync(List<VectorItem> vectorItems, Action<string>? progressCallback = null)
    {
        try
        {
            // Debug authentication setup
            var endpoint = _configuration["COSMOS_DB:ENDPOINT_DB"] ?? _configuration["COSMOS_DB__ENDPOINT_DB"];
            progressCallback?.Invoke($"🔑 Using managed identity (AAD token) authentication with endpoint: {endpoint}");
            progressCallback?.Invoke("ℹ️ Local authorization is disabled on this Cosmos DB account - using Azure AD authentication");
            
            // Debug environment variables for database and container
            var databaseName = _configuration["COSMOSDB_DATABASE_NAME"] ?? "vectordb";
            var containerName = _configuration["COSMOSDB_CONTAINER_NAME"] ?? "Container3";
            progressCallback?.Invoke($"🎯 Target database: {databaseName}, container: {containerName}");
            
            // Get database and container using environment configuration
            progressCallback?.Invoke($"🎯 Connecting to database: {databaseName}, container: {containerName}");
            
            var database = _cosmosClient.GetDatabase(databaseName);
            var container = database.GetContainer(containerName);
            
            // Verify connection first - this will test authentication
            progressCallback?.Invoke("🔍 Testing authentication by reading container properties...");
            try
            {
                var containerProperties = await container.ReadContainerAsync();
                progressCallback?.Invoke($"✅ Successfully authenticated! Connected to container: {containerProperties.Resource.Id}");
                progressCallback?.Invoke($"📊 Container throughput: {containerProperties.Resource.DefaultTimeToLive}");
                progressCallback?.Invoke($"🔧 Container partition key: {containerProperties.Resource.PartitionKeyPath}");
            }
            catch (CosmosException authEx) when (authEx.StatusCode == System.Net.HttpStatusCode.Unauthorized)
            {
                progressCallback?.Invoke($"❌ Authentication failed: {authEx.Message}");
                progressCallback?.Invoke($"🔍 StatusCode: {authEx.StatusCode}, SubStatusCode: {authEx.SubStatusCode}");
                progressCallback?.Invoke($"🆔 ActivityId: {authEx.ActivityId}");
                
                if (authEx.Message.Contains("Local Authorization is disabled"))
                {
                    progressCallback?.Invoke("🔧 The Cosmos DB account has local authorization disabled and requires Azure AD authentication.");
                    progressCallback?.Invoke("🔍 Checking if managed identity permissions are properly configured...");
                    progressCallback?.Invoke("💡 Role assignments can take up to 15 minutes after deployment to fully propagate.");
                    progressCallback?.Invoke("⏰ If this was recently deployed, please wait a few minutes and try again.");
                }
                else if (authEx.Message.Contains("Authorization header doesn't confirm to the required format"))
                {
                    progressCallback?.Invoke("🔧 Authorization header format error - this suggests a managed identity authentication issue.");
                    progressCallback?.Invoke("🔍 Possible causes:");
                    progressCallback?.Invoke("   • Role assignment principal ID mismatch");
                    progressCallback?.Invoke("   • Container app not using the correct managed identity");
                    progressCallback?.Invoke("   • Token acquisition failure");
                    progressCallback?.Invoke("💡 Let's check if the managed identity is properly attached to this container app...");
                }
                throw;
            }
            catch (CosmosException authEx) when (authEx.StatusCode == System.Net.HttpStatusCode.Forbidden)
            {
                progressCallback?.Invoke($"❌ Access forbidden: {authEx.Message}");
                progressCallback?.Invoke($"🔍 StatusCode: {authEx.StatusCode}, SubStatusCode: {authEx.SubStatusCode}");
                progressCallback?.Invoke($"🆔 ActivityId: {authEx.ActivityId}");
                progressCallback?.Invoke("🔧 This indicates the identity is authenticated but lacks permissions.");
                progressCallback?.Invoke("🔍 Checking role assignments for the managed identity...");
                throw;
            }
            catch (Exception authEx)
            {
                progressCallback?.Invoke($"❌ Unexpected authentication error: {authEx.Message}");
                progressCallback?.Invoke($"📋 Exception type: {authEx.GetType().Name}");
                throw;
            }
            
            // Check current document count before upload
            try
            {
                var queryDefinition = new QueryDefinition("SELECT COUNT(1) as DocumentCount FROM c");
                var queryIterator = container.GetItemQueryIterator<dynamic>(queryDefinition);
                var results = await queryIterator.ReadNextAsync();
                var currentCount = results.FirstOrDefault()?.DocumentCount ?? 0;
                progressCallback?.Invoke($"📊 Current document count in container: {currentCount}");
            }
            catch (Exception ex)
            {
                progressCallback?.Invoke($"⚠️ Could not check current document count: {ex.Message}");
            }
            
            progressCallback?.Invoke("📤 Starting document upload to Cosmos DB...");
            
            // Upload documents individually for better error tracking
            var totalUploaded = 0;
            var totalSkipped = 0;
            var totalErrors = 0;
            
            for (int i = 0; i < vectorItems.Count; i++)
            {
                var item = vectorItems[i];
                try
                {
                    var response = await container.CreateItemAsync(item, new PartitionKey(item.partitionKey));
                    totalUploaded++;
                    
                    if (i < 5 || i % 10 == 0) // Log first 5 and every 10th item
                    {
                        progressCallback?.Invoke($"✅ Uploaded: {item.title} (Status: {response.StatusCode}, RU: {response.RequestCharge})");
                    }
                }
                catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.Conflict)
                {
                    totalSkipped++;
                    if (i < 5 || i % 10 == 0)
                    {
                        progressCallback?.Invoke($"⏭️ Skipped (exists): {item.title}");
                    }
                }
                catch (Exception ex)
                {
                    totalErrors++;
                    var errorMsg = $"❌ Error uploading document {item.id} ({item.title}): {ex.Message}";
                    if (ex is CosmosException cosmosEx)
                    {
                        errorMsg += $" (StatusCode: {cosmosEx.StatusCode}, SubStatusCode: {cosmosEx.SubStatusCode}, ActivityId: {cosmosEx.ActivityId})";
                    }
                    progressCallback?.Invoke(errorMsg);
                    
                    // If this is an auth error, stop immediately
                    if (ex.Message.Contains("Unauthorized") || ex.Message.Contains("authorization") || ex.Message.Contains("authentication"))
                    {
                        progressCallback?.Invoke("🚨 Authentication error detected - stopping upload");
                        throw;
                    }
                }
                
                // Progress update every 10 items
                if ((i + 1) % 10 == 0 || i == vectorItems.Count - 1)
                {
                    var processed = i + 1;
                    var percentage = (int)((processed / (float)vectorItems.Count) * 100);
                    progressCallback?.Invoke($"📊 Progress: {processed}/{vectorItems.Count} ({percentage}%) - ✅Uploaded: {totalUploaded}, ⏭️Skipped: {totalSkipped}, ❌Errors: {totalErrors}");
                }
                
                // Small delay to avoid overwhelming the service
                if (i % 5 == 0 && i > 0)
                {
                    await Task.Delay(100);
                }
            }
            
            // Final verification - check document count after upload
            progressCallback?.Invoke("🔍 Verifying upload by checking final document count...");
            try
            {
                var queryDefinition = new QueryDefinition("SELECT COUNT(1) as DocumentCount FROM c");
                var queryIterator = container.GetItemQueryIterator<dynamic>(queryDefinition);
                var results = await queryIterator.ReadNextAsync();
                var finalCount = results.FirstOrDefault()?.DocumentCount ?? 0;
                progressCallback?.Invoke($"📊 Final document count in container: {finalCount}");
                
                if (finalCount == 0 && totalUploaded > 0)
                {
                    progressCallback?.Invoke("⚠️ WARNING: Upload reported success but container is still empty!");
                }
                else if (finalCount > 0)
                {
                    progressCallback?.Invoke($"🎉 SUCCESS: Container now contains {finalCount} documents!");
                }
            }
            catch (Exception ex)
            {
                progressCallback?.Invoke($"❌ Error verifying final count: {ex.Message}");
            }
            
            if (totalErrors > 0)
            {
                progressCallback?.Invoke($"⚠️ Upload completed with issues: ✅{totalUploaded} uploaded, ⏭️{totalSkipped} skipped, ❌{totalErrors} errors");
            }
            else
            {
                progressCallback?.Invoke($"🏁 Upload complete! ✅Total uploaded: {totalUploaded}, ⏭️Total skipped: {totalSkipped}");
            }
        }
        catch (Exception ex)
        {
            var errorMsg = $"❌ Critical error in upload process: {ex.Message}";
            if (ex is CosmosException cosmosEx)
            {
                errorMsg += $" (StatusCode: {cosmosEx.StatusCode}, SubStatusCode: {cosmosEx.SubStatusCode}, ActivityId: {cosmosEx.ActivityId})";
            }
            progressCallback?.Invoke(errorMsg);
            progressCallback?.Invoke($"Full exception details: {ex}");
            throw;
        }
    }

    public void Dispose()
    {
        _cosmosClient?.Dispose();
    }
}

// Data models for the sample data
public class SampleVectorDocument
{
    public string id { get; set; } = string.Empty;
    public string title { get; set; } = string.Empty;
    public string content { get; set; } = string.Empty;
    public string category { get; set; } = string.Empty;
    public List<float>? titleVector { get; set; }
    public List<float>? contentVector { get; set; }
}

// Updated VectorItem to match existing schema
public class VectorItem
{
    public string id { get; set; } = string.Empty;
    public string title { get; set; } = string.Empty;
    public string content { get; set; } = string.Empty;
    public string category { get; set; } = string.Empty;
    public float[] titleVector { get; set; } = Array.Empty<float>();
    public float[] contentVector { get; set; } = Array.Empty<float>();
    public string partitionKey { get; set; } = string.Empty;
}
