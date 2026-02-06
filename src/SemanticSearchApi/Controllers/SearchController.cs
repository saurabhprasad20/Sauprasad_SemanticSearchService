using Microsoft.AspNetCore.Mvc;
using SemanticSearchApi.Models;
using SemanticSearchApi.Services;

namespace SemanticSearchApi.Controllers;

[ApiController]
[Route("[controller]")]
public class SearchController : ControllerBase
{
    private readonly IVectorSearchService _vectorSearchService;
    private readonly ILogger<SearchController> _logger;

    public SearchController(
        IVectorSearchService vectorSearchService,
        ILogger<SearchController> logger)
    {
        _vectorSearchService = vectorSearchService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<IActionResult> Search([FromQuery] string query, [FromQuery] int topK = 5)
    {
        if (string.IsNullOrWhiteSpace(query))
        {
            return BadRequest(new { error = "Query parameter is required" });
        }

        if (topK < 1 || topK > 50)
        {
            return BadRequest(new { error = "topK must be between 1 and 50" });
        }

        if (!_vectorSearchService.IsInitialized)
        {
            return StatusCode(503, new { error = "Service is initializing, please try again shortly" });
        }

        try
        {
            var results = await _vectorSearchService.SearchAsync(query, topK);

            return Ok(new
            {
                query,
                resultsCount = results.Count,
                results
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing search request for query: {Query}", query);
            return StatusCode(500, new { error = "An error occurred processing your search" });
        }
    }

    [HttpPost]
    public async Task<IActionResult> SearchPost([FromBody] SearchRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Query))
        {
            return BadRequest(new { error = "Query is required" });
        }

        return await Search(request.Query, request.TopK);
    }
}
