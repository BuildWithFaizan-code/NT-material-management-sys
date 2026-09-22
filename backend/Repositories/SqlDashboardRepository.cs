using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Common;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories;

public class SqlDashboardRepository : IDashboardRepository
{
    private readonly string _connectionString;

    public SqlDashboardRepository(IConfiguration configuration)
    {
        _connectionString = DbConnectionHelper.ResolveConnectionString(configuration);
    }

    public async Task<MetricsDto?> GetMetricsAsync()
    {
        using var connection = new SqlConnection(_connectionString);

        const string sql = @"
            SELECT
                (SELECT COUNT(DISTINCT I_CODE) FROM stockregnew WHERE sr_stk='Y')           AS ActiveStocks,
                4.2                                                                         AS AvgLeadTime,
                (SELECT COALESCE(SUM(AMT/I_QTY), 0) FROM stockregnew WHERE sr_stk='Y' AND I_QTY<>0) AS ProcurementTotal,
                98.2                                                                        AS OptimizationScore";

        return await connection.QueryFirstOrDefaultAsync<MetricsDto>(sql);
    }

    public async Task<IEnumerable<VelocityDataPoint>> GetVelocityDataAsync(string metricType)
    {
        using var connection = new SqlConnection(_connectionString);

        var normalizedMetric = (metricType ?? string.Empty).Trim().ToLowerInvariant();
        string aggregateColumn = normalizedMetric switch
        {
            "material velocity" => "COALESCE(SUM(ABS(S.i_qty)), 0)",
            "transaction count" => "COUNT(*)",
            _ => "COALESCE(SUM(S.amt), 0)"
        };

        string sql = $@"
            WITH MonthsCTE AS (
                SELECT 0 AS Offset
                UNION ALL
                SELECT Offset + 1
                FROM MonthsCTE
                WHERE Offset < 5
            ),
            TimelineCTE AS (
                SELECT 
                    YEAR(DATEADD(MONTH, -Offset, GETDATE())) AS TargetYear,
                    MONTH(DATEADD(MONTH, -Offset, GETDATE())) AS TargetMonth,
                    FORMAT(DATEADD(MONTH, -Offset, GETDATE()), 'MMM') AS MonthLabel
                FROM MonthsCTE
            )
            SELECT 
                T.MonthLabel AS Month,
                CAST(COALESCE(D.Value, 0) AS INT) AS Value
            FROM TimelineCTE T
            LEFT JOIN (
                SELECT 
                    YEAR(S.dt) AS YearPart,
                    MONTH(S.dt) AS MonthPart,
                    {aggregateColumn} AS Value
                FROM stockregnew S
                WHERE S.sr_stk = 'Y'
                GROUP BY YEAR(S.dt), MONTH(S.dt)
            ) D ON T.TargetYear = D.YearPart AND T.TargetMonth = D.MonthPart
            ORDER BY T.TargetYear ASC, T.TargetMonth ASC";

        return await connection.QueryAsync<VelocityDataPoint>(sql);
    }

    public async Task<IEnumerable<AlertItem>> GetAlertsAsync()
    {
        using var connection = new SqlConnection(_connectionString);

        const string sql = @"
            SELECT
                NEWID()                                                     AS Id,
                I.I_NAME1                                                   AS ItemName,
                COALESCE(ROUND(SUM(S.i_qty),3), 0)                          AS CurrentStock,
                50.0                                                        AS SafetyThreshold,
                ISNULL(I.I_CODE, 'SKU')                                     AS Department,
                CASE WHEN COALESCE(ROUND(SUM(S.amt),2), 0) < 10 THEN 'High'
                     ELSE 'Low' END                                         AS Priority
            FROM ItemMst I
            LEFT JOIN stockregnew S ON I.I_CODE = S.i_code AND S.sr_stk='Y'
            GROUP BY I.I_CODE, I.I_NAME1
            HAVING COALESCE(ROUND(SUM(S.i_qty),3), 0) < 100
            ORDER BY CurrentStock ASC";

        return await connection.QueryAsync<AlertItem>(sql);
    }

    public async Task<IEnumerable<TransactionRecord>> GetTransactionsAsync()
    {
        using var connection = new SqlConnection(_connectionString);

        const string sql = @"
            SELECT TOP 20
                'TXN-' + CAST(S.SR_CODE AS VARCHAR) + '-' + FORMAT(S.dt, 'yyyyMMdd') AS TransactionId,
                I.I_NAME1                                                   AS MaterialDetail,
                ISNULL(L.LAB_NAME, 'General')                               AS Department,
                CAST(ROUND(S.i_qty,3) AS VARCHAR) + ' Kg'                    AS Quantity,
                S.amt                                                       AS Value,
                CASE WHEN ROUND(S.i_qty,3) > 0 THEN 'RECEIVED'
                     ELSE 'IN TRANSIT' END                                  AS Status
            FROM stockregnew S
            INNER JOIN ItemMst I ON S.I_CODE = I.I_CODE 
            INNER JOIN LABOURMST L ON S.KH_CODE = L.LAB_CODE
            WHERE S.MODE = 'GRNACC' AND S.sr_stk = 'Y'
            ORDER BY S.dt DESC";

        return await connection.QueryAsync<TransactionRecord>(sql);
    }

    public async Task<bool> UpdateAlertPriorityAsync(Guid id, string priority)
    {
        await Task.CompletedTask;
        return false;
    }

    public async Task<bool> DeleteAlertAsync(Guid id)
    {
        await Task.CompletedTask;
        return false;
    }
}