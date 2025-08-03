using System.Text.Json;
using Microsoft.Azure.Cosmos;
using Azure.Identity;
using Microsoft.Extensions.Configuration;

namespace DataSeeder;

class Program
{
    private static IConfiguration? _configuration;
    
    static async Task Main(string[] args)
    {
        Console.WriteLine("=== Azure Cosmos DB Vector Data Seeder ===");
        Console.WriteLine("This tool will load sample vector data from seed-data.json and seed it into your Cosmos DB container.\n");

        try
        {
            // Load configuration
            LoadConfiguration();
            
            // Validate configuration
            ValidateConfiguration();
            
            // Run seeding
            var seeder = new VectorDataSeeder(_configuration!);
            await seeder.SeedDataAsync();
            
            Console.WriteLine("\n✅ Data seeding completed successfully!");
            Console.WriteLine("You can now test the RAG functionality in your Blazor chat application.");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"\n❌ Error: {ex.Message}");
            Console.WriteLine("\nPlease check:");
            Console.WriteLine("- Your Cosmos DB connection is configured correctly");
            Console.WriteLine("- The container app has the required permissions");
            Console.WriteLine("- Database 'vectordb' and container 'Container3' exist");
            Console.WriteLine("- Vector search is enabled on your Cosmos DB account");
            
            Environment.Exit(1);
        }
    }

    private static void LoadConfiguration()
    {
        var builder = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
            .AddEnvironmentVariables();

        _configuration = builder.Build();
    }

    private static void ValidateConfiguration()
    {
        var cosmosEndpoint = _configuration!["COSMOS_DB:ENDPOINT_DB"];
        
        if (string.IsNullOrEmpty(cosmosEndpoint))
        {
            throw new InvalidOperationException(
                "Cosmos DB endpoint not configured. Please set COSMOS_DB:ENDPOINT_DB in appsettings.json or environment variables.");
        }

        Console.WriteLine($"✓ Cosmos DB Endpoint: {cosmosEndpoint}");
    }
}

public class VectorDataSeeder
{
    private readonly IConfiguration _configuration;
    private readonly CosmosClient _cosmosClient;
    
    public VectorDataSeeder(IConfiguration configuration)
    {
        _configuration = configuration;
        
        // Initialize Cosmos client with managed identity
        _cosmosClient = new CosmosClient(
            accountEndpoint: _configuration["COSMOS_DB:ENDPOINT_DB"],
            tokenCredential: new DefaultAzureCredential()
        );
    }

    public async Task SeedDataAsync()
    {
        Console.WriteLine("� Loading sample vector data from local file...");
        
        // Load sample data from local file
        var sampleData = await LoadSampleDataAsync();
        Console.WriteLine($"✓ Loaded {sampleData.Count} sample documents");
        
        // Transform to VectorItem format
        Console.WriteLine("🔄 Transforming data to match schema...");
        var vectorItems = TransformToVectorItems(sampleData);
        Console.WriteLine($"✓ Transformed {vectorItems.Count} documents");
        
        // Upload to Cosmos DB
        Console.WriteLine("☁️ Uploading to Cosmos DB...");
        await UploadToCosmosDbAsync(vectorItems);
    }

    private async Task<List<SampleVectorDocument>> LoadSampleDataAsync()
    {
        // Look for seed-data.json in the main project directory (two levels up)
        var projectRoot = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", ".."));
        var jsonFilePath = Path.Combine(projectRoot, "seed-data.json");
        
        if (!File.Exists(jsonFilePath))
        {
            // Try current directory as fallback
            jsonFilePath = Path.Combine(Directory.GetCurrentDirectory(), "seed-data.json");
            if (!File.Exists(jsonFilePath))
            {
                throw new FileNotFoundException($"Sample data file not found. Looked in:\n- {Path.Combine(projectRoot, "seed-data.json")}\n- {Path.Combine(Directory.GetCurrentDirectory(), "seed-data.json")}");
            }
        }
        
        Console.WriteLine($"📄 Loading data from: {jsonFilePath}");
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
        
        // Upload documents in batches to avoid throttling
        const int batchSize = 5;
        var totalUploaded = 0;
        var totalSkipped = 0;
        
        for (int i = 0; i < vectorItems.Count; i += batchSize)
        {
            var batch = vectorItems.Skip(i).Take(batchSize).ToList();
            var uploadTasks = batch.Select(async item =>
            {
                try
                {
                    await container.CreateItemAsync(item, new PartitionKey(item.partitionKey));
                    Console.WriteLine($"  ✓ Uploaded: {item.id} - {item.title}");
                    return true;
                }
                catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.Conflict)
                {
                    Console.WriteLine($"  ⚠ Skipped (exists): {item.id} - {item.title}");
                    return false;
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"  ❌ Error uploading {item.id}: {ex.Message}");
                    throw;
                }
            });
            
            var results = await Task.WhenAll(uploadTasks);
            totalUploaded += results.Count(r => r);
            totalSkipped += results.Count(r => !r);
            
            var progress = Math.Min(i + batchSize, vectorItems.Count);
            Console.WriteLine($"Progress: {progress}/{vectorItems.Count} processed");
            
            // Add small delay to avoid throttling
            await Task.Delay(200);
        }
        
        Console.WriteLine($"\n📊 Summary:");
        Console.WriteLine($"   • {totalUploaded} documents uploaded");
        Console.WriteLine($"   • {totalSkipped} documents skipped (already exist)");
        Console.WriteLine($"   • {vectorItems.Count} total documents processed");
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

// VectorItem to match existing schema
public class VectorItem
{
    public string id { get; set; } = string.Empty;
    public string title { get; set; } = string.Empty;
    public string content { get; set; } = string.Empty;
    public string category { get; set; } = string.Empty;
    public float[] titleVector { get; set; } = Array.Empty<float>();
    public string partitionKey { get; set; } = string.Empty;
}
