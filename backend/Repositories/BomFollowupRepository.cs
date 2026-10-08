using System;
using System.Collections.Generic;
using System.Data;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using MMSERP.Api.Common;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class BomFollowupRepository : IBomFollowupRepository
    {
        private readonly string _connectionString;

        public BomFollowupRepository(IConfiguration configuration)
        {
            _connectionString = DbConnectionHelper.ResolveConnectionString(configuration);
        }

        private IDbConnection CreateConnection() => new SqlConnection(_connectionString);

        public async Task<IEnumerable<BomFollowupDepartmentDto>> GetDepartmentsAsync()
        {
            const string sql = @"
                SELECT LAB_NAME AS LabName, LAB_CODE AS LabCode 
                FROM LABOURMST 
                WHERE (LAB_STATUS = '' OR LAB_STATUS IS NULL OR LAB_STATUS = 'YES') 
                ORDER BY LAB_NAME";

            using var conn = CreateConnection();
            return await conn.QueryAsync<BomFollowupDepartmentDto>(sql);
        }

        public async Task<IEnumerable<BomFollowupDivisionDto>> GetDivisionsAsync()
        {
            const string sql = @"
                SELECT KH_NAME AS KhName, KH_CODE AS KhCode 
                FROM KHATAMST 
                WHERE (KH_DISPLAY IS NULL OR KH_DISPLAY = 0) 
                ORDER BY KH_NAME";

            using var conn = CreateConnection();
            return await conn.QueryAsync<BomFollowupDivisionDto>(sql);
        }

        public async Task<IEnumerable<BomFollowupOrderTypeDto>> GetOrderTypesAsync()
        {
            const string sql = @"
                SELECT DISTINCT BOM_TYPE AS BomType 
                FROM BOMMST 
                WHERE [PURPOSE] = 'COSTING' 
                ORDER BY BOM_TYPE";

            using var conn = CreateConnection();
            return await conn.QueryAsync<BomFollowupOrderTypeDto>(sql);
        }

        public async Task<IEnumerable<BomFollowupRecordDto>> GetOpenRecordsAsync(
            DateTime asOnDate, int? departmentCode, int? divisionCode, string? orderType)
        {
            const string sql = @"
                SELECT A.BOMID AS [BomId], A.BOM_DATE AS [BomDate], D.LAB_CODE AS [LabCode], D.LAB_NAME AS [Department], 
                       E.STR_CODE AS [StrCode], E.STR_NAME AS [Branch], G.KH_CODE AS [KhCode], G.KH_NAME AS [Division], 
                       COALESCE(A.DESCRIPTION, B.I_NAME1, '') AS [MaterialName], A.I_CODE AS [MaterialCode], '' AS [MergeNo], 
                       CAST(A.QTY AS DECIMAL(18,3)) AS [Qty], CAST(A.QTY AS DECIMAL(18,3)) AS [Stock], 
                       A.[STATUS] AS [Status], A.BOM_EDATE AS [DtAndTime], A.BOM_USRNAME AS [User], 
                       A.BOM_COST AS [Rate], J.UNIT_NAME AS [Uqc], A.UNIT_CODE AS [Ucode] 
                FROM BOMMST AS A  
                LEFT JOIN ITEMMST AS B ON A.I_CODE = B.I_CODE  
                LEFT JOIN LABOURMST AS D ON A.BOM_DEPCODE = D.LAB_CODE 
                LEFT JOIN STOREMST AS E ON A.BOM_STRCODE = E.STR_CODE 
                LEFT JOIN SKUMST AS F ON A.I_CODE = F.SKU_CODE 
                LEFT JOIN KHATAMST AS G ON F.SKU_GRPCD = G.KH_CODE 
                LEFT JOIN UNITMST AS J ON A.UNIT_CODE = J.UNIT_CODE 
                WHERE BOM_DATE <= @AsOnDate AND PURPOSE = 'COSTING' AND (STATUS = 'OPEN')
                  AND (@DepartmentCode IS NULL OR @DepartmentCode = 0 OR D.LAB_CODE = @DepartmentCode)
                  AND (@DivisionCode IS NULL OR @DivisionCode = 0 OR G.KH_CODE = @DivisionCode)
                  AND (@OrderType IS NULL OR @OrderType = '' OR @OrderType = 'ALL' OR A.BOM_TYPE = @OrderType)
                ORDER BY BOM_DATE";

            using var conn = CreateConnection();
            return await conn.QueryAsync<BomFollowupRecordDto>(sql, new
            {
                AsOnDate = asOnDate,
                DepartmentCode = departmentCode,
                DivisionCode = divisionCode,
                OrderType = string.IsNullOrWhiteSpace(orderType) || orderType.Equals("ALL", StringComparison.OrdinalIgnoreCase)
                    ? null
                    : orderType
            });
        }

        public async Task<bool> IsDateLockedAsync(DateTime asOnDate)
        {
            const string sql = @"
                SELECT COUNT(1) 
                FROM LOCKDATAMST 
                WHERE CAST(@AsOnDate AS DATE) = CAST(LDM_STDT AS DATE)";

            using var conn = CreateConnection();
            var count = await conn.ExecuteScalarAsync<int>(sql, new { AsOnDate = asOnDate.Date });
            return count > 0;
        }

        public async Task<int> CloseBomBatchAsync(
            List<string> bomIds, DateTime asOnDate, string username, string companyName)
        {
            if (bomIds == null || bomIds.Count == 0) return 0;

            using var conn = (SqlConnection)CreateConnection();
            await conn.OpenAsync();
            using var tx = conn.BeginTransaction();

            try
            {
                // 1. Pre-save Lock Verification inside transaction
                const string lockCheckSql = @"
                    SELECT COUNT(1) 
                    FROM LOCKDATAMST 
                    WHERE CAST(@AsOnDate AS DATE) = CAST(LDM_STDT AS DATE)";
                var lockCount = await conn.ExecuteScalarAsync<int>(lockCheckSql, new { AsOnDate = asOnDate.Date }, tx);
                if (lockCount > 0)
                {
                    throw new InvalidOperationException($"The date {asOnDate:yyyy-MM-dd} is locked in LOCKDATAMST. Action rejected.");
                }

                var now = DateTime.UtcNow;
                int affectedTotal = 0;

                const string daybookSql = @"
                    INSERT INTO DAYBOOK(DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES(@DbDate, @DbUser, 'BILL OF MATERIAL CLOSE', 0, @BomId, 'EDIT', 'BOM', 1, @CompanyName)";

                const string updateBomSql = @"
                    UPDATE BOMMST 
                    SET Status = 'CLOSE', BOM_ClDate = @Now 
                    WHERE PURPOSE = 'Costing' AND BOMID = @BomId";

                foreach (var id in bomIds)
                {
                    if (string.IsNullOrWhiteSpace(id)) continue;
                    var bomId = id.Trim();

                    // Log DAYBOOK audit entry
                    await conn.ExecuteAsync(daybookSql, new
                    {
                        DbDate = now,
                        DbUser = string.IsNullOrWhiteSpace(username) ? "ADMIN" : username,
                        BomId = bomId,
                        CompanyName = string.IsNullOrWhiteSpace(companyName) ? "NEWTECHINFOSOL" : companyName
                    }, tx);

                    // Update BOM status
                    var rows = await conn.ExecuteAsync(updateBomSql, new
                    {
                        Now = now,
                        BomId = bomId
                    }, tx);

                    affectedTotal += rows;
                }

                tx.Commit();
                return affectedTotal;
            }
            catch
            {
                tx.Rollback();
                throw;
            }
        }
    }
}
