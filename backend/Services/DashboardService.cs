using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services;

public class DashboardService : IDashboardService
{
    private readonly IDashboardRepository _repository;

    public DashboardService(IDashboardRepository repository)
    {
        _repository = repository;
    }

    public async Task<MetricsDto> GetMetricsAsync()
    {
        var result = await _repository.GetMetricsAsync();
        return result ?? new MetricsDto
        {
            ActiveStocks = 0,
            AvgLeadTime = 0,
            ProcurementTotal = 0,
            OptimizationScore = 0,
        };
    }

    public Task<IEnumerable<VelocityDataPoint>> GetVelocityDataAsync(string metricType)
    {
        return _repository.GetVelocityDataAsync(metricType);
    }

    public Task<IEnumerable<AlertItem>> GetAlertsAsync()
    {
        return _repository.GetAlertsAsync();
    }

    public Task<IEnumerable<TransactionRecord>> GetTransactionsAsync()
    {
        return _repository.GetTransactionsAsync();
    }

    public Task<bool> UpdateAlertPriorityAsync(Guid id, string priority)
    {
        return _repository.UpdateAlertPriorityAsync(id, priority);
    }

    public Task<bool> DeleteAlertAsync(Guid id)
    {
        return _repository.DeleteAlertAsync(id);
    }
}
