namespace SemanticSearchApi.Models;

public class BirdRecord
{
    public string Name { get; set; } = string.Empty;
    public string ScientificName { get; set; } = string.Empty;
    public string Presence { get; set; } = string.Empty;
    public string Order { get; set; } = string.Empty;
    public string Family { get; set; } = string.Empty;

    public string GetFullText()
    {
        return $"{Name} ({ScientificName}) - {Presence} - Order: {Order}, Family: {Family}";
    }

    public string GetSearchableText()
    {
        var presenceText = Presence == "R" ? "resident species that breeds in India" : "winter visitor migratory species";
        return $"{Name}, scientific name {ScientificName}, {presenceText}, belongs to order {Order} and family {Family}";
    }
}
