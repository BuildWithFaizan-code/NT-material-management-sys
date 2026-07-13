using MMSERP.Api.Models;

namespace MMSERP.Api.Services;

public interface IDashboardService
{
    Task<MetricsDto> GetMetricsAsync();
    Task<IEnumerable<VelocityDataPoint>> GetVelocityDataAsync(string metricType);
    Task<IEnumerable<AlertItem>> GetAlertsAsync();
    Task<IEnumerable<TransactionRecord>> GetTransactionsAsync();
    Task<bool> UpdateAlertPriorityAsync(Guid id, string priority);
    Task<bool> DeleteAlertAsync(Guid id);
}
