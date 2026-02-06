using Microsoft.AspNetCore.Mvc;
using SemanticSearchApi.Services;

namespace SemanticSearchApi.Controllers;

[ApiController]
[Route("[controller]")]
public class HealthController : ControllerBase
{
    private readonly IVectorSearchService _vectorSearchService;
    private readonly ILogger<HealthController> _logger;

    public HealthController(
        IVectorSearchService vectorSearchService,
        ILogger<HealthController> logger)
    {
        _vectorSearchService = vectorSearchService;
        _logger = logger;
    }

    [HttpGet]
    public IActionResult Get()
    {
        var isHealthy = _vectorSearchService.IsInitialized;

        var response = new
        {
            status = isHealthy ? "healthy" : "initializing",
            timestamp = DateTime.UtcNow,
            service = "semantic-search-api",
            ready = isHealthy
        };

        if (!isHealthy)
        {
            _logger.LogWarning("Health check failed - service not initialized");
            return StatusCode(503, response);
        }

        return Ok(response);
    }
}
