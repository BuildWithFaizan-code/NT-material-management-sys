namespace MMSERP.Api.Models;

public record VelocityDataPoint
{
    public string Month { get; init; } = string.Empty;
    public int Value { get; init; }
}
