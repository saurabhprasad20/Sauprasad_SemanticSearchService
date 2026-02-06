using Azure.Identity;
using Azure.Storage.Blobs;
using CsvHelper;
using CsvHelper.Configuration;
using SemanticSearchApi.Models;
using System.Globalization;

namespace SemanticSearchApi.Services;

public class BlobStorageService : IBlobStorageService
{
    private readonly BlobContainerClient _containerClient;
    private readonly string _blobFileName;
    private readonly ILogger<BlobStorageService> _logger;

    public BlobStorageService(IConfiguration configuration, ILogger<BlobStorageService> logger)
    {
        _logger = logger;

        var storageUrl = configuration["BlobStorage:Url"]
            ?? throw new InvalidOperationException("BlobStorage:Url not configured");

        var containerName = configuration["BlobStorage:ContainerName"]
            ?? throw new InvalidOperationException("BlobStorage:ContainerName not configured");

        _blobFileName = configuration["BlobStorage:FileName"]
            ?? throw new InvalidOperationException("BlobStorage:FileName not configured");

        // Use DefaultAzureCredential which supports Managed Identity
        var credential = new DefaultAzureCredential();
        var blobServiceClient = new BlobServiceClient(new Uri(storageUrl), credential);
        _containerClient = blobServiceClient.GetBlobContainerClient(containerName);

        _logger.LogInformation("BlobStorageService initialized with container: {Container}", containerName);
    }

    public async Task<List<BirdRecord>> LoadBirdDataAsync()
    {
        try
        {
            _logger.LogInformation("Loading bird data from blob: {FileName}", _blobFileName);

            var blobClient = _containerClient.GetBlobClient(_blobFileName);

            using var stream = await blobClient.OpenReadAsync();
            using var reader = new StreamReader(stream);
            using var csv = new CsvReader(reader, new CsvConfiguration(CultureInfo.InvariantCulture)
            {
                HeaderValidated = null,
                MissingFieldFound = null
            });

            csv.Context.RegisterClassMap<BirdRecordMap>();
            var records = csv.GetRecords<BirdRecord>().ToList();

            // Filter out empty records
            records = records.Where(r => !string.IsNullOrWhiteSpace(r.Name)).ToList();

            _logger.LogInformation("Loaded {Count} bird records from blob storage", records.Count);

            return records;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error loading bird data from blob storage");
            throw;
        }
    }
}

public class BirdRecordMap : ClassMap<BirdRecord>
{
    public BirdRecordMap()
    {
        Map(m => m.Name).Name("name");
        Map(m => m.ScientificName).Name("scientific name");
        Map(m => m.Presence).Name("presence");
        Map(m => m.Order).Name("order");
        Map(m => m.Family).Name("family");
    }
}
