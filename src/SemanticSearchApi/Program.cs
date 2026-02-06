using SemanticSearchApi.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Register application services
builder.Services.AddSingleton<IEmbeddingService, EmbeddingService>();
builder.Services.AddSingleton<IBlobStorageService, BlobStorageService>();
builder.Services.AddSingleton<IVectorSearchService, VectorSearchService>();

// Add health checks
builder.Services.AddHealthChecks();

// Configure logging
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

var app = builder.Build();

// Configure the HTTP request pipeline
app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/swagger/v1/swagger.json", "Semantic Search API v1");
    options.RoutePrefix = string.Empty; // Serve Swagger UI at root URL
});

app.MapControllers();
app.MapHealthChecks("/healthz");

// Initialize vector search service on startup
var logger = app.Services.GetRequiredService<ILogger<Program>>();
logger.LogInformation("Starting Semantic Search API...");

var vectorSearchService = app.Services.GetRequiredService<IVectorSearchService>();

// Initialize in background to not block startup
_ = Task.Run(async () =>
{
    try
    {
        logger.LogInformation("Initializing vector search service in background...");
        await vectorSearchService.InitializeAsync();
        logger.LogInformation("Vector search service initialization complete");
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Failed to initialize vector search service");
    }
});

logger.LogInformation("Semantic Search API started successfully");

app.Run();
