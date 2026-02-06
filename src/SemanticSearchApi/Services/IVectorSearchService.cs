using SemanticSearchApi.Models;

namespace SemanticSearchApi.Services;

public interface IVectorSearchService
{
    Task InitializeAsync();
    Task<List<SearchResult>> SearchAsync(string query, int topK = 5);
    bool IsInitialized { get; }
}
