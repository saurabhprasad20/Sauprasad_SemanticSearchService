namespace SemanticSearchApi.Models;

public class SearchResult
{
    public string Name { get; set; } = string.Empty;
    public string ScientificName { get; set; } = string.Empty;
    public string Presence { get; set; } = string.Empty;
    public string Order { get; set; } = string.Empty;
    public string Family { get; set; } = string.Empty;
    public double Score { get; set; }
    public string Content { get; set; } = string.Empty;
}
