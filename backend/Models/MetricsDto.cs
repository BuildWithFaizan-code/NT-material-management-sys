namespace MMSERP.Api.Models;

public record MetricsDto
{
    public int ActiveStocks { get; init; }
    public double AvgLeadTime { get; init; }
    public decimal ProcurementTotal { get; init; }
    public double OptimizationScore { get; init; }
}
