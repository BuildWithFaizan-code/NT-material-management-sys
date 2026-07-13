using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services;

public class MockDashboardService : IDashboardService
{
    private readonly IDashboardRepository _repository;
    private static readonly List<AlertItem> _alerts = GenerateAlerts();
    private static readonly object _lock = new();

    public MockDashboardService(IDashboardRepository repository)
    {
        _repository = repository;
    }

    public Task<MetricsDto> GetMetricsAsync()
    {
        var dto = new MetricsDto
        {
            ActiveStocks = 1284,
            AvgLeadTime = 4.2,
            ProcurementTotal = 12_400_000.00m,
            OptimizationScore = 98.2
        };
        return Task.FromResult(dto);
    }

    public Task<IEnumerable<VelocityDataPoint>> GetVelocityDataAsync(string metricType)
    {
        var data = metricType switch
        {
            "Profit & Loss" => new List<VelocityDataPoint>
            {
                new() { Month = "Jan", Value = 45 },
                new() { Month = "Feb", Value = 52 },
                new() { Month = "Mar", Value = 38 },
                new() { Month = "Apr", Value = 61 },
                new() { Month = "May", Value = 55 },
                new() { Month = "Jun", Value = 72 },
                new() { Month = "Jul", Value = 68 },
                new() { Month = "Aug", Value = 80 },
                new() { Month = "Sep", Value = 74 },
                new() { Month = "Oct", Value = 91 },
                new() { Month = "Nov", Value = 85 },
                new() { Month = "Dec", Value = 97 },
            },
            "Sales & Purchase" => new List<VelocityDataPoint>
            {
                new() { Month = "Jan", Value = 120 },
                new() { Month = "Feb", Value = 135 },
                new() { Month = "Mar", Value = 110 },
                new() { Month = "Apr", Value = 148 },
                new() { Month = "May", Value = 155 },
                new() { Month = "Jun", Value = 170 },
                new() { Month = "Jul", Value = 162 },
                new() { Month = "Aug", Value = 180 },
                new() { Month = "Sep", Value = 175 },
                new() { Month = "Oct", Value = 195 },
                new() { Month = "Nov", Value = 188 },
                new() { Month = "Dec", Value = 210 },
            },
            "Inventory Turnover" => new List<VelocityDataPoint>
            {
                new() { Month = "Jan", Value = 3 },
                new() { Month = "Feb", Value = 4 },
                new() { Month = "Mar", Value = 5 },
                new() { Month = "Apr", Value = 4 },
                new() { Month = "May", Value = 6 },
                new() { Month = "Jun", Value = 5 },
                new() { Month = "Jul", Value = 7 },
                new() { Month = "Aug", Value = 6 },
                new() { Month = "Sep", Value = 8 },
                new() { Month = "Oct", Value = 7 },
                new() { Month = "Nov", Value = 9 },
                new() { Month = "Dec", Value = 8 },
            },
            "Procurement Trends" => new List<VelocityDataPoint>
            {
                new() { Month = "Jan", Value = 28 },
                new() { Month = "Feb", Value = 35 },
                new() { Month = "Mar", Value = 42 },
                new() { Month = "Apr", Value = 30 },
                new() { Month = "May", Value = 48 },
                new() { Month = "Jun", Value = 55 },
                new() { Month = "Jul", Value = 50 },
                new() { Month = "Aug", Value = 62 },
                new() { Month = "Sep", Value = 58 },
                new() { Month = "Oct", Value = 70 },
                new() { Month = "Nov", Value = 65 },
                new() { Month = "Dec", Value = 78 },
            },
            _ => new List<VelocityDataPoint>
            {
                new() { Month = "Jan", Value = 65 },
                new() { Month = "Feb", Value = 72 },
                new() { Month = "Mar", Value = 58 },
                new() { Month = "Apr", Value = 85 },
                new() { Month = "May", Value = 78 },
                new() { Month = "Jun", Value = 92 },
                new() { Month = "Jul", Value = 88 },
                new() { Month = "Aug", Value = 105 },
                new() { Month = "Sep", Value = 95 },
                new() { Month = "Oct", Value = 112 },
                new() { Month = "Nov", Value = 108 },
                new() { Month = "Dec", Value = 125 },
            },
        };

        return Task.FromResult(data.AsEnumerable());
    }

    public Task<IEnumerable<AlertItem>> GetAlertsAsync()
    {
        lock (_lock)
        {
            return Task.FromResult(_alerts.Select(a => a with { }).AsEnumerable());
        }
    }

    public Task<IEnumerable<TransactionRecord>> GetTransactionsAsync()
    {
        var records = new List<TransactionRecord>
        {
            new()
            {
                TransactionId = "TXN-9021",
                MaterialDetail = "Recycled Polyester Thread",
                Department = "Spinning Dept",
                Quantity = "450 Kg",
                Value = 245000.00m,
                Status = "RECEIVED"
            },
            new()
            {
                TransactionId = "TXN-9022",
                MaterialDetail = "Dyed Indigo Denim Yarn",
                Department = "Weaving Unit",
                Quantity = "1200 Kg",
                Value = 812500.00m,
                Status = "IN TRANSIT"
            },
            new()
            {
                TransactionId = "TXN-9019",
                MaterialDetail = "Cotton Bales Grade A",
                Department = "Spinning Dept",
                Quantity = "2000 Kg",
                Value = 345000.00m,
                Status = "RECEIVED"
            },
            new()
            {
                TransactionId = "TXN-9018",
                MaterialDetail = "Reactive Dye Blue",
                Department = "Dyeing Unit",
                Quantity = "85 Ltrs",
                Value = 42500.00m,
                Status = "RECEIVED"
            },
            new()
            {
                TransactionId = "TXN-9017",
                MaterialDetail = "Packing Corrugated Boxes",
                Department = "Finishing Dept",
                Quantity = "500 Pcs",
                Value = 62500.00m,
                Status = "IN TRANSIT"
            },
        };

        return Task.FromResult(records.AsEnumerable());
    }

    public Task<bool> UpdateAlertPriorityAsync(Guid id, string priority)
    {
        lock (_lock)
        {
            var item = _alerts.FirstOrDefault(a => a.Id == id);
            if (item == null) return Task.FromResult(false);

            item.Priority = priority;
            return Task.FromResult(true);
        }
    }

    public Task<bool> DeleteAlertAsync(Guid id)
    {
        lock (_lock)
        {
            var removed = _alerts.RemoveAll(a => a.Id == id);
            return Task.FromResult(removed > 0);
        }
    }

    private static List<AlertItem> GenerateAlerts()
    {
        return new List<AlertItem>
        {
            new()
            {
                Id = Guid.NewGuid(),
                ItemName = "Cotton Yarn 40s",
                CurrentStock = 12,
                SafetyThreshold = 50,
                Department = "Warehouse A",
                Priority = "High"
            },
            new()
            {
                Id = Guid.NewGuid(),
                ItemName = "Dye Fixer Agent",
                CurrentStock = 8,
                SafetyThreshold = 30,
                Department = "Warehouse B",
                Priority = "Low"
            },
            new()
            {
                Id = Guid.NewGuid(),
                ItemName = "Packing Material",
                CurrentStock = 5,
                SafetyThreshold = 100,
                Department = "Warehouse A",
                Priority = "High"
            },
            new()
            {
                Id = Guid.NewGuid(),
                ItemName = "Spare Parts Kit",
                CurrentStock = 3,
                SafetyThreshold = 25,
                Department = "Warehouse C",
                Priority = "Low"
            },
            new()
            {
                Id = Guid.NewGuid(),
                ItemName = "Raw Silk Batch",
                CurrentStock = 18,
                SafetyThreshold = 40,
                Department = "Warehouse B",
                Priority = "Low"
            },
        };
    }
}
