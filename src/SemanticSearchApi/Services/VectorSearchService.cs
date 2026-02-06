using SemanticSearchApi.Models;
using System.Numerics.Tensors;

namespace SemanticSearchApi.Services;

public class VectorSearchService : IVectorSearchService
{
    private readonly IBlobStorageService _blobStorageService;
    private readonly IEmbeddingService _embeddingService;
    private readonly ILogger<VectorSearchService> _logger;

    private List<BirdRecord> _birdRecords = new();
    private List<float[]> _embeddings = new();
    private bool _isInitialized = false;

    public bool IsInitialized => _isInitialized;

    public VectorSearchService(
        IBlobStorageService blobStorageService,
        IEmbeddingService embeddingService,
        ILogger<VectorSearchService> logger)
    {
        _blobStorageService = blobStorageService;
        _embeddingService = embeddingService;
        _logger = logger;
    }

    public async Task InitializeAsync()
    {
        if (_isInitialized)
        {
            _logger.LogInformation("Vector search service already initialized");
            return;
        }

        _logger.LogInformation("Initializing vector search service...");

        try
        {
            // Load bird data from blob storage
            _birdRecords = await _blobStorageService.LoadBirdDataAsync();
            _logger.LogInformation("Loaded {Count} bird records", _birdRecords.Count);

            // Generate embeddings for all birds
            _embeddings = new List<float[]>();
            for (int i = 0; i < _birdRecords.Count; i++)
            {
                var bird = _birdRecords[i];
                var embedding = await _embeddingService.GenerateEmbeddingAsync(bird.GetSearchableText());
                _embeddings.Add(embedding);

                if ((i + 1) % 10 == 0)
                {
                    _logger.LogInformation("Generated embeddings for {Count}/{Total} birds",
                        i + 1, _birdRecords.Count);
                }
            }

            _isInitialized = true;
            _logger.LogInformation("Vector search service initialized successfully with {Count} embeddings",
                _embeddings.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error initializing vector search service");
            throw;
        }
    }

    public async Task<List<SearchResult>> SearchAsync(string query, int topK = 5)
    {
        if (!_isInitialized)
        {
            throw new InvalidOperationException("Vector search service not initialized");
        }

        _logger.LogInformation("Searching for: {Query} (topK: {TopK})", query, topK);

        try
        {
            // Generate embedding for query
            var queryEmbedding = await _embeddingService.GenerateEmbeddingAsync(query);

            // Calculate cosine similarity with all bird embeddings
            var scores = new List<(int Index, double Score)>();
            for (int i = 0; i < _embeddings.Count; i++)
            {
                var similarity = CosineSimilarity(queryEmbedding, _embeddings[i]);
                scores.Add((i, similarity));
            }

            // Sort by score descending and take top K
            var topResults = scores
                .OrderByDescending(s => s.Score)
                .Take(topK)
                .ToList();

            // Build search results
            var results = topResults.Select(r =>
            {
                var bird = _birdRecords[r.Index];
                return new SearchResult
                {
                    Name = bird.Name,
                    ScientificName = bird.ScientificName,
                    Presence = bird.Presence,
                    Order = bird.Order,
                    Family = bird.Family,
                    Score = r.Score,
                    Content = bird.GetFullText()
                };
            }).ToList();

            _logger.LogInformation("Found {Count} results for query: {Query}", results.Count, query);

            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error performing search for query: {Query}", query);
            throw;
        }
    }

    private static double CosineSimilarity(float[] vector1, float[] vector2)
    {
        if (vector1.Length != vector2.Length)
        {
            throw new ArgumentException("Vectors must have the same length");
        }

        var span1 = vector1.AsSpan();
        var span2 = vector2.AsSpan();

        var dotProduct = TensorPrimitives.Dot(span1, span2);
        var magnitude1 = Math.Sqrt(TensorPrimitives.Dot(span1, span1));
        var magnitude2 = Math.Sqrt(TensorPrimitives.Dot(span2, span2));

        if (magnitude1 == 0 || magnitude2 == 0)
        {
            return 0;
        }

        return dotProduct / (magnitude1 * magnitude2);
    }
}
