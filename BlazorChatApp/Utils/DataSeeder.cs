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
        
        // Initialize Cosmos client with managed identity
        _cosmosClient = new CosmosClient(
            accountEndpoint: _configuration["COSMOS_DB:ENDPOINT_DB"],
            tokenCredential: new DefaultAzureCredential()
        );
    }

    public async Task SeedSampleDataAsync()
    {
        try
        {
            Console.WriteLine("Starting data seeding process...");
            
            // Load sample data from local file
            var sampleData = await LoadSampleDataAsync();
            Console.WriteLine($"Loaded {sampleData.Count} sample documents from local file");
            
            // Transform to VectorItem format
            var vectorItems = TransformToVectorItems(sampleData);
            Console.WriteLine($"Transformed {vectorItems.Count} documents to VectorItem format");
            
            // Upload to Cosmos DB
            await UploadToCosmosDbAsync(vectorItems);
            Console.WriteLine("Successfully seeded data to Cosmos DB!");
        }
        catch (Exception ex)
        {
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
                // Add partition key - using category as partition key strategy
                partitionKey = sample.category
            };
            
            vectorItems.Add(vectorItem);
        }
        
        return vectorItems;
    }

    private async Task UploadToCosmosDbAsync(List<VectorItem> vectorItems)
    {
        // Get database and container
        var database = _cosmosClient.GetDatabase("vectordb");
        var container = database.GetContainer("Container3");
        
        Console.WriteLine("Uploading documents to Cosmos DB...");
        
        // Upload documents in batches to avoid throttling
        const int batchSize = 10;
        var totalUploaded = 0;
        
        for (int i = 0; i < vectorItems.Count; i += batchSize)
        {
            var batch = vectorItems.Skip(i).Take(batchSize).ToList();
            var tasks = batch.Select(async item =>
            {
                try
                {
                    await container.CreateItemAsync(item, new PartitionKey(item.partitionKey));
                    Console.WriteLine($"Uploaded document: {item.id} - {item.title}");
                }
                catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.Conflict)
                {
                    Console.WriteLine($"Document {item.id} already exists, skipping...");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error uploading document {item.id}: {ex.Message}");
                    throw;
                }
            });
            
            await Task.WhenAll(tasks);
            totalUploaded += batch.Count;
            Console.WriteLine($"Progress: {totalUploaded}/{vectorItems.Count} documents uploaded");
            
            // Add small delay to avoid throttling
            await Task.Delay(100);
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
    public string partitionKey { get; set; } = string.Empty;
}
