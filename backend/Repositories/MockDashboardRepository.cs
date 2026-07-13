using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories;

public class MockDashboardRepository : IDashboardRepository
{
    public Task<MetricsDto?> GetMetricsAsync()
    {
        throw new NotImplementedException(
            "Dapper repository not yet connected. Use MockDashboardService for mock data.");
    }

    public Task<IEnumerable<VelocityDataPoint>> GetVelocityDataAsync(string metricType)
    {
        throw new NotImplementedException(
            "Dapper repository not yet connected. Use MockDashboardService for mock data.");
    }

    public Task<IEnumerable<AlertItem>> GetAlertsAsync()
    {
        throw new NotImplementedException(
            "Dapper repository not yet connected. Use MockDashboardService for mock data.");
    }

    public Task<IEnumerable<TransactionRecord>> GetTransactionsAsync()
    {
        throw new NotImplementedException(
            "Dapper repository not yet connected. Use MockDashboardService for mock data.");
    }

    public Task<bool> UpdateAlertPriorityAsync(Guid id, string priority)
    {
        throw new NotImplementedException(
            "Dapper repository not yet connected. Use MockDashboardService for mock data.");
    }

    public Task<bool> DeleteAlertAsync(Guid id)
    {
        throw new NotImplementedException(
            "Dapper repository not yet connected. Use MockDashboardService for mock data.");
    }
}
