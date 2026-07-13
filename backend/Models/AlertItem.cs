namespace MMSERP.Api.Models;

public record AlertItem
{
    public Guid Id { get; init; }
    public string ItemName { get; init; } = string.Empty;
    public double CurrentStock { get; init; }
    public double SafetyThreshold { get; init; }
    public string Department { get; init; } = string.Empty;
    public string Priority { get; set; } = "Low";
}
