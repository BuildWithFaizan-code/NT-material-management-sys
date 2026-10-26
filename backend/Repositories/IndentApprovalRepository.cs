using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using MMSERP.Api.Common;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class IndentApprovalRepository : IIndentApprovalRepository
    {
        private readonly string _connectionString;
        private readonly IConfiguration _configuration;

        public IndentApprovalRepository(IConfiguration configuration)
        {
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
            _connectionString = DbConnectionHelper.ResolveConnectionString(configuration);
        }

        private IDbConnection CreateConnection() => new SqlConnection(_connectionString);

        public async Task<IndentApprovalLookupsDto> GetLookupsAsync()
        {
            var lookups = new IndentApprovalLookupsDto();
            using var conn = CreateConnection();

            // 1. Indent Numbers
            const string sqlIndents = @"
                SELECT DISTINCT IND_CODE 
                FROM INDENT_MASTER 
                WHERE IND_CODE IS NOT NULL AND IND_CODE <> '' 
                ORDER BY IND_CODE DESC";
            var indents = await conn.QueryAsync<string>(sqlIndents);
            lookups.IndentNumbers = indents.ToList();

            // 2. Departments
            const string sqlDepts = @"
                SELECT LAB_CODE AS LabCode, LAB_NAME AS LabName 
                FROM LABOURMST 
                WHERE (LAB_STATUS = '' OR LAB_STATUS IS NULL OR LAB_STATUS = 'YES') 
                ORDER BY LAB_NAME";
            var depts = await conn.QueryAsync<IndentApprovalDepartmentDto>(sqlDepts);
            lookups.Departments = depts.ToList();

            // 3. Items with pending/open indents
            const string sqlItems = @"
                SELECT DISTINCT IM.I_CODE AS Code, IM.I_NAME1 AS ItemName 
                FROM ITEMMST IM 
                WHERE IM.I_CODE IN (
                    SELECT CODE FROM INDENT_DET 
                    WHERE (ISAPPRO = 0 OR ISAPPRO IS NULL) 
                      AND (ISREJECT = 0 OR ISREJECT IS NULL) 
                      AND (ISHOLD = 0 OR ISHOLD IS NULL)
                )
                ORDER BY IM.I_NAME1";
            var items = (await conn.QueryAsync<IndentApprovalItemLookupDto>(sqlItems)).ToList();

            if (items.Count == 0)
            {
                const string sqlFallbackItems = @"
                    SELECT DISTINCT TOP 100 IM.I_CODE AS Code, IM.I_NAME1 AS ItemName 
                    FROM ITEMMST IM 
                    WHERE IM.I_CODE IN (SELECT CODE FROM INDENT_DET)
                    ORDER BY IM.I_NAME1";
                items = (await conn.QueryAsync<IndentApprovalItemLookupDto>(sqlFallbackItems)).ToList();
            }

            lookups.Items = items;
            return lookups;
        }

        public async Task<IEnumerable<IndentApprovalRecordDto>> GetRecordsAsync(
            DateTime? asOnDate,
            DateTime? fromDate,
            DateTime? toDate,
            string? statusFilter,
            string? indCode,
            int? deptCode,
            string? itemCode)
        {
            var sqlBuilder = new System.Text.StringBuilder(@"
                SELECT 
                    B.ISAPPRO AS IsAppro, 
                    A.IND_CODE AS IndCode, 
                    A.IND_DATE AS IndDate, 
                    COALESCE(C.LAB_NAME, 'GENERAL') AS LabName, 
                    B.CODE AS Code, 
                    COALESCE(IM.I_NAME1, B.DESCRIPTION, '') AS ItName, 
                    CAST(B.QTY AS FLOAT) AS Qty, 
                    CAST(B.RATE AS FLOAT) AS Rate, 
                    CAST(B.TOTALVALUE AS FLOAT) AS TotalValue, 
                    B.INDDET_CODE AS InddetCode, 
                    B.ISREJECT AS IsReject, 
                    B.ISHOLD AS IsHold, 
                    COALESCE(B.REQNO, '') AS ReqNo, 
                    (SELECT MAX(PO_NO) FROM PUR_ORDR_DET AS POD WHERE POD.IND_CODE = B.IND_CODE AND POD.I_CODE = B.CODE) AS ProcessDo 
                FROM ((INDENT_MASTER AS A INNER JOIN INDENT_DET AS B ON A.IND_CODE = B.IND_CODE) 
                LEFT OUTER JOIN LABOURMST AS C ON A.DEPT_CODE = C.LAB_CODE) 
                LEFT JOIN ITEMMST AS IM ON IM.I_CODE = B.CODE 
                WHERE 1 = 1");

            var parameters = new DynamicParameters();

            // Status Filter Logic
            var status = (statusFilter ?? "PENDING").Trim().ToUpperInvariant();
            switch (status)
            {
                case "APPROVED":
                    sqlBuilder.Append(" AND B.ISAPPRO = 1");
                    break;
                case "REJECTED":
                    sqlBuilder.Append(" AND B.ISREJECT = 1");
                    break;
                case "HOLD":
                    sqlBuilder.Append(" AND B.ISHOLD = 1");
                    break;
                case "ALL":
                    // No status condition
                    break;
                case "PENDING":
                default:
                    sqlBuilder.Append(@" AND (B.ISREJECT = 0 OR B.ISREJECT IS NULL) 
                                         AND (B.ISHOLD = 0 OR B.ISHOLD IS NULL) 
                                         AND (B.ISAPPRO = 0 OR B.ISAPPRO IS NULL)");
                    break;
            }

            // Date Filters
            if (asOnDate.HasValue)
            {
                sqlBuilder.Append(" AND A.IND_DATE <= @AsOnDate");
                parameters.Add("AsOnDate", asOnDate.Value.Date.AddDays(1).AddTicks(-1));
            }

            if (fromDate.HasValue)
            {
                sqlBuilder.Append(" AND A.IND_DATE >= @FromDate");
                parameters.Add("FromDate", fromDate.Value.Date);
            }

            if (toDate.HasValue)
            {
                sqlBuilder.Append(" AND A.IND_DATE <= @ToDate");
                parameters.Add("ToDate", toDate.Value.Date.AddDays(1).AddTicks(-1));
            }

            // Lookup Filters
            if (!string.IsNullOrWhiteSpace(indCode))
            {
                sqlBuilder.Append(" AND A.IND_CODE = @IndCode");
                parameters.Add("IndCode", indCode.Trim());
            }

            if (deptCode.HasValue && deptCode.Value > 0)
            {
                sqlBuilder.Append(" AND A.DEPT_CODE = @DeptCode");
                parameters.Add("DeptCode", deptCode.Value);
            }

            if (!string.IsNullOrWhiteSpace(itemCode))
            {
                sqlBuilder.Append(" AND B.CODE = @ItemCode");
                parameters.Add("ItemCode", itemCode.Trim());
            }

            sqlBuilder.Append(" ORDER BY A.IND_DATE DESC, A.IND_CODE DESC, B.INDDET_CODE ASC");

            using var conn = CreateConnection();
            return await conn.QueryAsync<IndentApprovalRecordDto>(sqlBuilder.ToString(), parameters);
        }

        public async Task<bool> IsDateLockedAsync(DateTime approvalDate)
        {
            const string sql = @"
                SELECT COUNT(1) 
                FROM LOCKDATAMST 
                WHERE CAST(@ApprovalDate AS DATE) = CAST(LDM_STDT AS DATE)";

            using var conn = CreateConnection();
            var count = await conn.ExecuteScalarAsync<int>(sql, new { ApprovalDate = approvalDate.Date });
            return count > 0;
        }

        public async Task<IndentApprovalActionResult> ProcessApprovalBatchAsync(
            IndentApprovalActionRequest request,
            string username)
        {
            if (request == null || request.Items == null || request.Items.Count == 0)
            {
                return new IndentApprovalActionResult
                {
                    Success = false,
                    Message = "No indent items selected for processing."
                };
            }

            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);
            var action = (request.Action ?? "APPROVE").Trim().ToUpperInvariant();
            var appDate = request.ApprovalDate == default ? DateTime.UtcNow : request.ApprovalDate;

            using var conn = (SqlConnection)CreateConnection();
            await conn.OpenAsync();
            using var tx = conn.BeginTransaction();

            try
            {
                // 1. Verify Date Lock
                const string lockCheckSql = @"
                    SELECT COUNT(1) 
                    FROM LOCKDATAMST 
                    WHERE CAST(@AppDate AS DATE) = CAST(LDM_STDT AS DATE)";
                var lockCount = await conn.ExecuteScalarAsync<int>(lockCheckSql, new { AppDate = appDate.Date }, tx);
                if (lockCount > 0)
                {
                    throw new InvalidOperationException($"The date {appDate:yyyy-MM-dd} is locked in LOCKDATAMST. Action rejected.");
                }

                int totalAffected = 0;
                var distinctIndCodes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

                foreach (var item in request.Items)
                {
                    if (string.IsNullOrWhiteSpace(item.IndCode)) continue;
                    distinctIndCodes.Add(item.IndCode.Trim());

                    // Audit Logging into DAYBOOK
                    const string daybookSql = @"
                        INSERT INTO DAYBOOK(DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME) 
                        VALUES (GETDATE(), @DbUser, @DeptName, 0, @IndentCode, '', 'IDA', 1, @CompanyName)";
                    await conn.ExecuteAsync(daybookSql, new
                    {
                        DbUser = string.IsNullOrWhiteSpace(username) ? "ADMIN" : username.Trim().ToUpperInvariant(),
                        DeptName = string.IsNullOrWhiteSpace(item.DepartmentName) ? "GENERAL" : item.DepartmentName.Trim(),
                        IndentCode = item.IndCode.Trim(),
                        CompanyName = companyName
                    }, tx);

                    // Update Indent_Det based on action
                    string updateLineSql;
                    switch (action)
                    {
                        case "REJECT":
                            updateLineSql = @"
                                UPDATE Indent_Det 
                                SET isAppro = 0, isReject = 1, isHold = 0, Ind_AppDt = @AppDate 
                                WHERE Ind_Code = @IndCode 
                                  AND (IndDet_Code = @InddetCode OR (code = @Code AND @InddetCode <= 0))";
                            break;
                        case "HOLD":
                            updateLineSql = @"
                                UPDATE Indent_Det 
                                SET isAppro = 0, isReject = 0, isHold = 1, Ind_AppDt = @AppDate 
                                WHERE Ind_Code = @IndCode 
                                  AND (IndDet_Code = @InddetCode OR (code = @Code AND @InddetCode <= 0))";
                            break;
                        case "RESET":
                            updateLineSql = @"
                                UPDATE Indent_Det 
                                SET isAppro = 0, isReject = 0, isHold = 0, Ind_AppDt = NULL 
                                WHERE Ind_Code = @IndCode 
                                  AND (IndDet_Code = @InddetCode OR (code = @Code AND @InddetCode <= 0))";
                            break;
                        case "APPROVE":
                        default:
                            updateLineSql = @"
                                UPDATE Indent_Det 
                                SET isAppro = 1, isReject = 0, isHold = 0, Ind_AppDt = @AppDate 
                                WHERE Ind_Code = @IndCode 
                                  AND (IndDet_Code = @InddetCode OR (code = @Code AND @InddetCode <= 0))";
                            break;
                    }

                    var rows = await conn.ExecuteAsync(updateLineSql, new
                    {
                        IndCode = item.IndCode.Trim(),
                        InddetCode = item.InddetCode,
                        Code = item.Code?.Trim() ?? string.Empty,
                        AppDate = appDate
                    }, tx);

                    totalAffected += rows;
                }

                // Header Synchronization per distinct Indent Voucher
                foreach (var indCode in distinctIndCodes)
                {
                    // 1. Partial Approval Reset: If ANY line is not approved, header IsAppro = 0
                    const string headerResetSql = @"
                        UPDATE Indent_master 
                        SET IsAppro = 0, AppDate = NULL 
                        WHERE ind_code = @IndCode 
                          AND Ind_Code IN (SELECT DISTINCT ind_code FROM indent_det WHERE isappro = 0 OR isappro IS NULL)";
                    await conn.ExecuteAsync(headerResetSql, new { IndCode = indCode }, tx);

                    // 2. Full Approval Finalization: If ALL lines are approved, header IsAppro = 1
                    const string headerFinalizeSql = @"
                        UPDATE Indent_master 
                        SET IsAppro = 1, AppDate = @AppDate 
                        WHERE ind_code = @IndCode 
                          AND Ind_Code IN (
                              SELECT DISTINCT ind_Code 
                              FROM indent_det AS a 
                              WHERE a.ind_code = @IndCode 
                              GROUP BY ind_code 
                              HAVING COUNT(ind_Code) <= (SELECT COUNT(*) FROM indent_det WHERE ind_Code = a.ind_code AND isappro = 1)
                          )";
                    await conn.ExecuteAsync(headerFinalizeSql, new { IndCode = indCode, AppDate = appDate }, tx);
                }

                tx.Commit();

                string actionLabel = action switch
                {
                    "REJECT" => "rejected",
                    "HOLD" => "placed on hold",
                    "RESET" => "reset to pending",
                    _ => "approved"
                };

                return new IndentApprovalActionResult
                {
                    Success = true,
                    Message = $"Successfully {actionLabel} {totalAffected} indent item(s).",
                    AffectedCount = totalAffected
                };
            }
            catch (Exception)
            {
                tx.Rollback();
                throw;
            }
        }
    }
}
