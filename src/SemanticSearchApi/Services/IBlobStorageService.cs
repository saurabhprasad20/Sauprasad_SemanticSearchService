using SemanticSearchApi.Models;

namespace SemanticSearchApi.Services;

public interface IBlobStorageService
{
    Task<List<BirdRecord>> LoadBirdDataAsync();
}
