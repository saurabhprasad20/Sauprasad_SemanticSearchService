using Azure;
using Azure.AI.OpenAI;
using Azure.Identity;
using OpenAI.Embeddings;

namespace SemanticSearchApi.Services;

public class EmbeddingService : IEmbeddingService
{
    private readonly AzureOpenAIClient _client;
    private readonly string _deploymentName;
    private readonly ILogger<EmbeddingService> _logger;

    public EmbeddingService(IConfiguration configuration, ILogger<EmbeddingService> logger)
    {
        _logger = logger;

        var endpoint = configuration["AzureOpenAI:Endpoint"]
            ?? throw new InvalidOperationException("AzureOpenAI:Endpoint not configured");

        _deploymentName = configuration["AzureOpenAI:EmbeddingDeployment"]
            ?? throw new InvalidOperationException("AzureOpenAI:EmbeddingDeployment not configured");

        // Use DefaultAzureCredential which supports Managed Identity
        var credential = new DefaultAzureCredential();
        _client = new AzureOpenAIClient(new Uri(endpoint), credential);

        _logger.LogInformation("EmbeddingService initialized with endpoint: {Endpoint}", endpoint);
    }

    public async Task<float[]> GenerateEmbeddingAsync(string text)
    {
        try
        {
            var embeddingClient = _client.GetEmbeddingClient(_deploymentName);
            var response = await embeddingClient.GenerateEmbeddingAsync(text);

            var embedding = response.Value.ToFloats().ToArray();

            _logger.LogDebug("Generated embedding for text: {Text} (dimension: {Dim})",
                text.Substring(0, Math.Min(50, text.Length)), embedding.Length);

            return embedding;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating embedding for text: {Text}", text);
            throw;
        }
    }
}
