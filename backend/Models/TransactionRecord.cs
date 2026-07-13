namespace MMSERP.Api.Models;

public record TransactionRecord
{
    public string TransactionId { get; init; } = string.Empty;
    public string MaterialDetail { get; init; } = string.Empty;
    public string Department { get; init; } = string.Empty;
    public string Quantity { get; init; } = string.Empty;
    public decimal Value { get; init; }
    public string Status { get; init; } = string.Empty;
}
