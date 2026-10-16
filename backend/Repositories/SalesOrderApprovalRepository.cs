using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using MMSERP.Api.Common;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class SalesOrderApprovalRepository : ISalesOrderApprovalRepository
    {
        private readonly string _connectionString;
        private readonly ILogger<SalesOrderApprovalRepository> _logger;

        public SalesOrderApprovalRepository(IConfiguration configuration, ILogger<SalesOrderApprovalRepository> logger)
        {
            _connectionString = DbConnectionHelper.ResolveConnectionString(configuration);
            _logger = logger;
        }

        private SqlConnection CreateConnection() => new(_connectionString);

        public async Task<SoApprovalLookupsDto> GetLookupsAsync()
        {
            using var conn = CreateConnection();
            await conn.OpenAsync();

            // 1. Departments from LABOURMST
            const string deptsSql = @"
                SELECT LAB_NAME AS LabName, LAB_CODE AS LabCode 
                FROM LABOURMST 
                WHERE (LAB_STATUS='' OR LAB_STATUS IS NULL OR LAB_STATUS='YES') 
                ORDER BY LAB_NAME;";

            // 2. Customers / Parties with Sales Orders
            const string partiesSql = @"
                SELECT DISTINCT P.P_CODE AS PCode, P.P_NAME AS PName 
                FROM PARTYMST AS P 
                WHERE P.P_CODE IN (
                    SELECT DISTINCT A.P_CODE 
                    FROM SAL_ORD_MST AS A 
                    INNER JOIN SAL_ORDR_DET AS B ON A.SO_NO = B.SO_NO
                    WHERE A.P_CODE IS NOT NULL AND A.P_CODE <> 0
                ) 
                ORDER BY P.P_NAME;";

            // 3. Sales Order Numbers
            const string ordersSql = @"
                SELECT DISTINCT SO_NO 
                FROM SAL_ORD_MST 
                WHERE SO_NO IS NOT NULL AND SO_NO <> '' 
                ORDER BY SO_NO;";

            // 4. Distinct Item Names & Codes from Orders
            const string itemsSql = @"
                SELECT DISTINCT D.I_CODE AS ItCode, D.I_NAME1 AS ItemName 
                FROM ITEMMST AS D 
                WHERE D.I_CODE IN (SELECT DISTINCT I_CODE FROM SAL_ORDR_DET WHERE I_CODE IS NOT NULL AND I_CODE <> '')
                  AND (D.I_HSN IS NOT NULL AND D.I_HSN <> '')
                ORDER BY D.I_NAME1;";

            var depts = (await conn.QueryAsync<SoApprovalDepartmentDto>(deptsSql)).ToList();
            var parties = (await conn.QueryAsync<SoApprovalCustomerDto>(partiesSql)).ToList();
            var orders = (await conn.QueryAsync<string>(ordersSql)).ToList();
            var items = (await conn.QueryAsync<SoApprovalItemLookupDto>(itemsSql)).ToList();

            return new SoApprovalLookupsDto
            {
                Departments = depts,
                Customers = parties,
                OrderNumbers = orders,
                Items = items
            };
        }

        public async Task<bool> CheckDateLockAsync(DateTime date)
        {
            using var conn = CreateConnection();
            await conn.OpenAsync();
            const string sql = "SELECT COUNT(1) FROM LOCKDATAMST WHERE CAST(LDM_STDT AS DATE) = CAST(@Date AS DATE);";
            var count = await conn.ExecuteScalarAsync<int>(sql, new { Date = date.Date });
            return count > 0;
        }

        public async Task<IEnumerable<SoApprovalRecordDto>> GetRecordsAsync(SoApprovalFilterQuery filter)
        {
            using var conn = CreateConnection();
            await conn.OpenAsync();

            var sb = new StringBuilder(@"
                SELECT 
                    A.SO_NO AS SalOrdNo,
                    A.SO_DATE AS SoDate,
                    ISNULL(C.LAB_NAME, 'GENERAL') AS LabName,
                    ISNULL(A.DEPT_CODE, 0) AS DeptCode,
                    ISNULL(E.P_NAME, 'CUSTOMER') AS PartyName,
                    ISNULL(A.P_CODE, 0) AS PartyCode,
                    ISNULL(D.I_CODE, '') AS ItCode,
                    ISNULL(D.I_NAME1, '') AS ItemName,
                    CAST(ISNULL(B.QTY, 0) AS DECIMAL(18, 2)) AS Qty,
                    CAST(ISNULL(B.RATE, 0) AS DECIMAL(18, 2)) AS Rate,
                    CAST(ISNULL(B.AMOUNT, 0) AS DECIMAL(18, 2)) AS Amount,
                    ISNULL(B.S_ID, 0) AS SId,
                    CAST(ISNULL(B.ISAPPRO, 0) AS INT) AS IsAppro,
                    CAST(ISNULL(B.ISREJECT, 0) AS INT) AS IsReject,
                    CAST(ISNULL(B.ISHOLD, 0) AS INT) AS IsHold,
                    CAST(ISNULL(B.CLOSESO, 0) AS INT) AS CloseSo,
                    CAST(ISNULL(B.ISREC, 0) AS INT) AS IsRec,
                    ISNULL(B.IND_CODE, '') AS IndCode,
                    ISNULL(CAST(B.SOD_CLOSREM AS VARCHAR(MAX)), '') AS SodClosRem,
                    0 AS ProcessDo,
                    ISNULL(E.P_MOBILE, '') AS CellNo
                FROM SAL_ORD_MST AS A 
                LEFT JOIN SAL_ORDR_DET AS B ON A.SO_NO = B.SO_NO 
                LEFT JOIN LABOURMST AS C ON A.DEPT_CODE = C.LAB_CODE 
                LEFT JOIN ITEMMST AS D ON B.I_CODE = D.I_CODE 
                LEFT JOIN PARTYMST AS E ON A.P_CODE = E.P_CODE 
                WHERE A.SO_NO <> '' AND B.S_ID IS NOT NULL ");

            var parameters = new DynamicParameters();

            // Status View Mode
            var viewMode = (filter.ViewMode ?? "PENDING").Trim().ToUpperInvariant();
            switch (viewMode)
            {
                case "APPROVED":
                    sb.Append(" AND (B.ISAPPRO <> 0) ");
                    break;
                case "REJECTED":
                    sb.Append(" AND (B.ISREJECT <> 0) ");
                    break;
                case "HOLD":
                    sb.Append(" AND (B.ISHOLD <> 0) ");
                    break;
                case "CLOSE":
                    sb.Append(" AND (B.CLOSESO <> 0) ");
                    break;
                case "UNCLOSE":
                    sb.Append(" AND (B.CLOSESO = 0 OR B.CLOSESO IS NULL) ");
                    break;
                case "PENDING":
                default:
                    sb.Append(@" AND (B.ISAPPRO = 0 OR B.ISAPPRO IS NULL) 
                                 AND (B.ISREJECT = 0 OR B.ISREJECT IS NULL) 
                                 AND (B.ISHOLD = 0 OR B.ISHOLD IS NULL) 
                                 AND (B.ISREC = 0 OR B.ISREC IS NULL) 
                                 AND (B.CLOSESO = 0 OR B.CLOSESO IS NULL) ");
                    break;
            }

            // Dynamic Filters
            if (filter.DeptCode.HasValue && filter.DeptCode.Value > 0)
            {
                sb.Append(" AND (A.DEPT_CODE = @DeptCode OR B.DEP_CODE = @DeptCode) ");
                parameters.Add("DeptCode", filter.DeptCode.Value);
            }

            if (filter.PartyCode.HasValue && filter.PartyCode.Value > 0)
            {
                sb.Append(" AND A.P_CODE = @PartyCode ");
                parameters.Add("PartyCode", filter.PartyCode.Value);
            }

            if (!string.IsNullOrWhiteSpace(filter.SoNo))
            {
                sb.Append(" AND A.SO_NO LIKE @SoNo ");
                parameters.Add("SoNo", $"%{filter.SoNo.Trim()}%");
            }

            if (!string.IsNullOrWhiteSpace(filter.ItemSearch))
            {
                sb.Append(" AND (D.I_CODE LIKE @ItemSearch OR D.I_NAME1 LIKE @ItemSearch) ");
                parameters.Add("ItemSearch", $"%{filter.ItemSearch.Trim()}%");
            }

            if (filter.FromDate.HasValue)
            {
                sb.Append(" AND A.SO_DATE >= @FromDate ");
                parameters.Add("FromDate", filter.FromDate.Value.Date);
            }

            if (filter.ToDate.HasValue)
            {
                sb.Append(" AND A.SO_DATE <= @ToDate ");
                parameters.Add("ToDate", filter.ToDate.Value.Date.AddDays(1).AddTicks(-1));
            }

            sb.Append(" ORDER BY A.SO_DATE DESC, A.SO_NO DESC, B.S_ID ASC;");

            return await conn.QueryAsync<SoApprovalRecordDto>(sb.ToString(), parameters);
        }

        public async Task<int> ExecuteStatusActionAsync(SoApprovalActionRequest request, string username, string companyName)
        {
            if (request.Items == null || request.Items.Count == 0) return 0;

            using var conn = CreateConnection();
            await conn.OpenAsync();
            using var tx = conn.BeginTransaction();

            try
            {
                var actionType = (request.ActionType ?? "Approve").Trim();
                var remark = request.Remark ?? string.Empty;
                var approvalDate = request.ApprovalDate.Date;

                string lineUpdateSql;
                string daybookAction;
                const string daybookType = "POA";

                switch (actionType.ToLowerInvariant())
                {
                    case "reject":
                        lineUpdateSql = @"
                            UPDATE Sal_Ordr_Det 
                            SET isAppro = 0, isReject = -1, isHold = 0, Closeso = 0, SOD_ClosRem = @Remark 
                            WHERE So_No = @SoNo AND S_Id = @SId;";
                        daybookAction = "REJECT";
                        break;

                    case "hold":
                        lineUpdateSql = @"
                            UPDATE Sal_Ordr_Det 
                            SET isAppro = 0, isReject = 0, isHold = -1, Closeso = 0, SOD_ClosRem = @Remark 
                            WHERE So_No = @SoNo AND S_Id = @SId;";
                        daybookAction = "HOLD";
                        break;

                    case "close":
                        lineUpdateSql = @"
                            UPDATE Sal_Ordr_Det 
                            SET Closeso = -1, SOD_ClosRem = @Remark 
                            WHERE So_No = @SoNo AND S_Id = @SId;";
                        daybookAction = "CLOSE";
                        break;

                    case "unclose":
                        lineUpdateSql = @"
                            UPDATE Sal_Ordr_Det 
                            SET Closeso = 0, SOD_ClosRem = '' 
                            WHERE So_No = @SoNo AND S_Id = @SId;";
                        daybookAction = "UNCLOSE";
                        break;

                    case "approve":
                    default:
                        lineUpdateSql = @"
                            UPDATE Sal_Ordr_Det 
                            SET isAppro = -1, isReject = 0, isHold = 0, Closeso = 0, So_AppDt = @ApprovalDate, SOD_ClosRem = @Remark 
                            WHERE So_No = @SoNo AND S_Id = @SId;";
                        daybookAction = "";
                        break;
                }

                const string daybookSql = @"
                    INSERT INTO DAYBOOK (DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME) 
                    VALUES (GETDATE(), @ActingUser, @DepartmentName, 0, @SoNo, @DbAction, @DbTyp, 1, @CompanyName);";

                int affectedLines = 0;
                var touchedSoNos = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

                foreach (var item in request.Items)
                {
                    var updated = await conn.ExecuteAsync(lineUpdateSql, new
                    {
                        SoNo = item.SoNo,
                        SId = item.SId,
                        ApprovalDate = approvalDate,
                        Remark = remark
                    }, tx);

                    if (updated > 0)
                    {
                        affectedLines += updated;
                        touchedSoNos.Add(item.SoNo);

                        var deptName = string.IsNullOrWhiteSpace(item.DepartmentName) ? "REGULAR" : item.DepartmentName;
                        await conn.ExecuteAsync(daybookSql, new
                        {
                            ActingUser = username.Trim(),
                            DepartmentName = deptName,
                            SoNo = item.SoNo,
                            DbAction = daybookAction,
                            DbTyp = daybookType,
                            CompanyName = companyName
                        }, tx);
                    }
                }

                // Header Synchronization in Sal_Ord_Mst
                foreach (var soNo in touchedSoNos)
                {
                    // 1. Reset header if any unapproved item exists in this SO
                    const string resetHeaderSql = @"
                        UPDATE Sal_Ord_Mst 
                        SET Approved = 0, AppDate = NULL 
                        WHERE So_no = @SoNo 
                          AND So_No IN (SELECT DISTINCT So_no FROM Sal_Ordr_Det WHERE isappro = 0 OR isappro IS NULL);";
                    await conn.ExecuteAsync(resetHeaderSql, new { SoNo = soNo }, tx);

                    // 2. Fully approve header if ALL items in this SO are approved
                    const string fullApproveHeaderSql = @"
                        UPDATE Sal_Ord_Mst 
                        SET Approved = -1, AppDate = @ApprovalDate 
                        WHERE So_no = @SoNo 
                          AND So_No IN (
                              SELECT DISTINCT So_No 
                              FROM Sal_Ordr_Det AS a 
                              GROUP BY So_No 
                              HAVING COUNT(So_No) <= (SELECT COUNT(*) FROM Sal_Ordr_Det WHERE So_No = a.So_No AND isappro <> 0)
                          );";
                    await conn.ExecuteAsync(fullApproveHeaderSql, new { SoNo = soNo, ApprovalDate = approvalDate }, tx);

                    // 3. Close header if all items closed
                    if (actionType.Equals("close", StringComparison.OrdinalIgnoreCase))
                    {
                        const string closeHeaderSql = @"
                            UPDATE Sal_Ord_Mst 
                            SET CloseSO = -1 
                            WHERE So_no = @SoNo 
                              AND So_No IN (
                                  SELECT DISTINCT So_No 
                                  FROM Sal_Ordr_Det AS a 
                                  GROUP BY So_No 
                                  HAVING COUNT(So_No) <= (SELECT COUNT(*) FROM Sal_Ordr_Det WHERE So_No = a.So_No AND closeso <> 0)
                              );";
                        await conn.ExecuteAsync(closeHeaderSql, new { SoNo = soNo }, tx);
                    }
                    else if (actionType.Equals("unclose", StringComparison.OrdinalIgnoreCase))
                    {
                        const string uncloseHeaderSql = @"
                            UPDATE Sal_Ord_Mst 
                            SET CloseSO = 0 
                            WHERE So_no = @SoNo;";
                        await conn.ExecuteAsync(uncloseHeaderSql, new { SoNo = soNo }, tx);
                    }
                }

                tx.Commit();
                return affectedLines;
            }
            catch (Exception ex)
            {
                tx.Rollback();
                _logger.LogError(ex, "Transaction rolled back while executing status action '{Action}' on SOs", request.ActionType);
                throw;
            }
        }
    }
}
