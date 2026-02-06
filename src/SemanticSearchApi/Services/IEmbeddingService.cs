namespace SemanticSearchApi.Services;

public interface IEmbeddingService
{
    Task<float[]> GenerateEmbeddingAsync(string text);
}
