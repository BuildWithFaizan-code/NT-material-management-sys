using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using MMSERP.Api.Common;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class PurchaseOrderAdvanceRepository : IPurchaseOrderAdvanceRepository
    {
        private readonly string _connectionString;
        private readonly string _databaseLocation;
        private readonly ILogger<PurchaseOrderAdvanceRepository> _logger;

        public PurchaseOrderAdvanceRepository(
            IConfiguration configuration,
            ILogger<PurchaseOrderAdvanceRepository> logger)
        {
            _connectionString = DbConnectionHelper.ResolveConnectionString(configuration);
            _logger = logger;

            try
            {
                var builder = new SqlConnectionStringBuilder(_connectionString);
                _databaseLocation = !string.IsNullOrWhiteSpace(builder.InitialCatalog)
                    ? builder.InitialCatalog
                    : "LWHL24_SQL";
            }
            catch
            {
                _databaseLocation = "LWHL24_SQL";
            }
        }

        private SqlConnection CreateConnection() => new(_connectionString);

        public async Task<IEnumerable<PoAdvancePartyLookupDto>> GetApprovedPoPartiesAsync()
        {
            using var conn = CreateConnection();
            await conn.OpenAsync();

            const string sql = @"
                SELECT PM.P_CODE AS PCode, PM.P_NAME AS PName 
                FROM PARTYMST AS PM 
                WHERE PM.P_CODE IN (
                    SELECT POM.P_CODE 
                    FROM PUR_ORD_MST AS POM, PUR_ORDR_DET AS POD 
                    WHERE POM.PO_NO = POD.PO_NO AND ISAPPRO <> 0
                ) 
                ORDER BY PM.P_NAME;";

            return await conn.QueryAsync<PoAdvancePartyLookupDto>(sql);
        }

        public async Task<IEnumerable<string>> GetApprovedPosForPartyAsync(int partyCode)
        {
            using var conn = CreateConnection();
            await conn.OpenAsync();

            const string sql = @"
                SELECT PO_NO 
                FROM PUR_ORD_MST 
                WHERE P_CODE = @PartyCode 
                  AND APPROVED <> 0 
                  AND (ISREC = 0 OR ISREC IS NULL)
                ORDER BY PO_DATE DESC, PO_NO DESC;";

            var result = await conn.QueryAsync<string>(sql, new { PartyCode = partyCode });
            return result.Where(s => !string.IsNullOrWhiteSpace(s)).ToList();
        }

        public async Task<PoAdvanceHeaderDetailsDto?> GetPoHeaderDetailsAsync(string poNo, DateTime appDate)
        {
            using var conn = CreateConnection();
            await conn.OpenAsync();

            const string headerSql = @"
                SELECT CAST(ISNULL(NETAMT, 0) AS DECIMAL(18,2)) AS NetAmt, 
                       PO_DATE AS PoDate,
                       ISNULL(Supp_Ref, '') AS SuppRef,
                       ISNULL(PTerms, '') AS PTerms,
                       ISNULL(DTerms, '') AS DTerms,
                       ISNULL(Remark, '') AS Remark,
                       ISNULL(PO_Mode, '') AS PoMode,
                       CAST(ISNULL(Adv, 0) AS DECIMAL(18,2)) AS AdvAgreed
                FROM PUR_ORD_MST 
                WHERE LTRIM(RTRIM(PO_NO)) = LTRIM(RTRIM(@PoNo));";

            var header = await conn.QueryFirstOrDefaultAsync<dynamic>(headerSql, new { PoNo = poNo });
            if (header == null) return null;

            decimal netAmt = Convert.ToDecimal(header.NetAmt);
            DateTime? poDate = header.PoDate != null ? Convert.ToDateTime(header.PoDate) : null;
            string suppRef = Convert.ToString(header.SuppRef) ?? string.Empty;
            string pTerms = Convert.ToString(header.PTerms) ?? string.Empty;
            string dTerms = Convert.ToString(header.DTerms) ?? string.Empty;
            string remark = Convert.ToString(header.Remark) ?? string.Empty;
            string poMode = Convert.ToString(header.PoMode) ?? string.Empty;
            decimal advAgreed = Convert.ToDecimal(header.AdvAgreed);

            const string priorAdvSql = @"
                SELECT CAST(ISNULL(SUM(APP_AMT + APP_LESS), 0) AS DECIMAL(18,2)) AS TotGiv 
                FROM POADVANCEMST 
                WHERE LTRIM(RTRIM(PO_NO)) = LTRIM(RTRIM(@PoNo)) 
                  AND CAST(APP_DT AS DATE) <= CAST(@AppDate AS DATE);";

            var totGivObj = await conn.ExecuteScalarAsync<object?>(priorAdvSql, new { PoNo = poNo, AppDate = appDate });
            decimal totGiv = totGivObj != null && totGivObj != DBNull.Value ? Convert.ToDecimal(totGivObj) : 0m;
            decimal pendingAmt = netAmt - totGiv;

            return new PoAdvanceHeaderDetailsDto
            {
                PoNo = poNo,
                PoDate = poDate,
                NetAmt = netAmt,
                TotGiv = totGiv,
                PendingAmt = pendingAmt,
                SuppRef = suppRef,
                PTerms = pTerms,
                DTerms = dTerms,
                Remark = remark,
                PoMode = poMode,
                AdvAgreed = advAgreed
            };
        }

        public async Task<IEnumerable<PoAdvanceHistoryRecordDto>> GetPoAdvanceHistoryAsync(string poNo)
        {
            using var conn = CreateConnection();
            await conn.OpenAsync();

            const string sql = @"
                SELECT PO.PO_ID AS PoId, PO.PO_NO AS PoNo, POM.PO_DATE AS PoDate, PO.APP_DT AS AppDt, 
                       ISNULL(PO.APP_EMODE, '') AS AppEMode, PO.APP_MDATE AS AppMDate, 
                       ISNULL(PM.P_CODE, 0) AS PartyId,
                       ISNULL(PM.P_NAME, '') AS PartyName, 
                       CAST(ISNULL(PO.APP_AMT, 0) AS DECIMAL(18,2)) AS AppAmt, 
                       CAST(ISNULL(PO.APP_LESS, 0) AS DECIMAL(18,2)) AS AppLess, 
                       CAST(ISNULL(PO.APP_BAMT, 0) AS DECIMAL(18,2)) AS AppBAmt, 
                       ISNULL(PO.APP_REMARK, '') AS AppRemark, 
                       ISNULL(PO.APP_USRNAME, '') AS AppUsrName,
                       ISNULL(NULLIF(C.LSM_CHEQUENO, ''), ISNULL(PO.APP_LOCMODE, '')) AS ChequeNo 
                FROM ((POADVANCEMST AS PO 
                LEFT JOIN PUR_ORD_MST AS POM ON LTRIM(RTRIM(PO.PO_NO)) = LTRIM(RTRIM(POM.PO_NO)))
                LEFT JOIN PARTYMST AS PM ON PO.APP_MID = PM.P_CODE) 
                LEFT JOIN LEDGERSUBMST AS C ON (PO.APP_LOCMODE = C.LSM_CODE AND PO.APP_MID = C.LSM_ACCCODE) 
                WHERE LTRIM(RTRIM(PO.PO_NO)) = LTRIM(RTRIM(@PoNo)) 
                ORDER BY PO.APP_DT, PO.PO_ID;";

            return await conn.QueryAsync<PoAdvanceHistoryRecordDto>(sql, new { PoNo = poNo });
        }

        public async Task<IEnumerable<PoAdvanceHistoryRecordDto>> GetAllAdvancesAsync(string? searchQuery = null, int limit = 500)
        {
            using var conn = CreateConnection();
            await conn.OpenAsync();

            const string sql = @"
                SELECT TOP (@Limit) 
                       PO.PO_ID AS PoId, PO.PO_NO AS PoNo, POM.PO_DATE AS PoDate, PO.APP_DT AS AppDt, 
                       ISNULL(PO.APP_EMODE, '') AS AppEMode, PO.APP_MDATE AS AppMDate, 
                       ISNULL(PM.P_CODE, 0) AS PartyId,
                       ISNULL(PM.P_NAME, '') AS PartyName, 
                       CAST(ISNULL(PO.APP_AMT, 0) AS DECIMAL(18,2)) AS AppAmt, 
                       CAST(ISNULL(PO.APP_LESS, 0) AS DECIMAL(18,2)) AS AppLess, 
                       CAST(ISNULL(PO.APP_BAMT, 0) AS DECIMAL(18,2)) AS AppBAmt, 
                       ISNULL(PO.APP_REMARK, '') AS AppRemark, 
                       ISNULL(PO.APP_USRNAME, '') AS AppUsrName,
                       ISNULL(NULLIF(C.LSM_CHEQUENO, ''), ISNULL(PO.APP_LOCMODE, '')) AS ChequeNo 
                FROM ((POADVANCEMST AS PO 
                LEFT JOIN PUR_ORD_MST AS POM ON LTRIM(RTRIM(PO.PO_NO)) = LTRIM(RTRIM(POM.PO_NO)))
                LEFT JOIN PARTYMST AS PM ON PO.APP_MID = PM.P_CODE) 
                LEFT JOIN LEDGERSUBMST AS C ON (PO.APP_LOCMODE = C.LSM_CODE AND PO.APP_MID = C.LSM_ACCCODE) 
                WHERE (@SearchQuery IS NULL OR @SearchQuery = '' 
                       OR PO.PO_NO LIKE '%' + @SearchQuery + '%' 
                       OR PM.P_NAME LIKE '%' + @SearchQuery + '%' 
                       OR PO.APP_REMARK LIKE '%' + @SearchQuery + '%' 
                       OR PO.APP_LOCMODE LIKE '%' + @SearchQuery + '%'
                       OR C.LSM_CHEQUENO LIKE '%' + @SearchQuery + '%') 
                ORDER BY PO.APP_DT DESC, PO.PO_ID DESC;";

            var effectiveLimit = limit > 0 ? limit : 500;
            return await conn.QueryAsync<PoAdvanceHistoryRecordDto>(sql, new { SearchQuery = searchQuery?.Trim(), Limit = effectiveLimit });
        }

        public async Task<IEnumerable<PoAdvancePartySummaryDto>> GetPartyAdvanceSummariesAsync(int partyCode)
        {
            using var conn = CreateConnection();
            await conn.OpenAsync();

            const string sql = @"
                SELECT PO.PO_NO AS PoNo, POM.PO_DATE AS PoDate, 
                       CAST(ISNULL(PO.APP_BAMT, 0) AS DECIMAL(18,2)) AS AppBAmt, 
                       CAST(ISNULL(SUM(PO.APP_AMT), 0) AS DECIMAL(18,2)) AS TotalAdv 
                FROM ((POADVANCEMST AS PO 
                LEFT JOIN PUR_ORD_MST AS POM ON LTRIM(RTRIM(POM.PO_NO)) = LTRIM(RTRIM(PO.PO_NO))) 
                LEFT JOIN PARTYMST AS PM ON POM.P_CODE = PM.P_CODE) 
                WHERE PM.P_CODE = @PartyCode 
                GROUP BY PO.PO_NO, POM.PO_DATE, PO.APP_BAMT
                ORDER BY POM.PO_DATE DESC, PO.PO_NO DESC;";

            return await conn.QueryAsync<PoAdvancePartySummaryDto>(sql, new { PartyCode = partyCode });
        }

        public async Task<bool> CheckDateLockAsync(DateTime date)
        {
            using var conn = CreateConnection();
            await conn.OpenAsync();

            const string sql = @"SELECT COUNT(1) FROM LOCKDATAMST WHERE @TargetDate = LDM_STDT;";
            var count = await conn.ExecuteScalarAsync<int>(sql, new { TargetDate = date.Date });
            return count > 0;
        }

        public async Task<int> CreateAdvanceAsync(PoAdvanceCreateRequest request, string username)
        {
            using var conn = CreateConnection();
            await conn.OpenAsync();
            using var tx = conn.BeginTransaction();

            try
            {
                // 1. Lock Date Verification
                const string lockCheckSql = @"SELECT COUNT(1) FROM LOCKDATAMST WHERE @TargetDate = LDM_STDT;";
                var lockCount = await conn.ExecuteScalarAsync<int>(lockCheckSql, new { TargetDate = request.AppDt.Date }, tx);
                if (lockCount > 0)
                {
                    throw new InvalidOperationException($"Transactions for date {request.AppDt:yyyy-MM-dd} are locked in LOCKDATAMST. Cannot post advance.");
                }

                // 2. Fetch Net Amount for BAmt
                const string poAmtSql = @"SELECT CAST(ISNULL(NETAMT, 0) AS DECIMAL(18,2)) FROM PUR_ORD_MST WHERE LTRIM(RTRIM(PO_NO)) = LTRIM(RTRIM(@PoNo));";
                var bAmtObj = await conn.ExecuteScalarAsync<object?>(poAmtSql, new { PoNo = request.PoNo }, tx);
                decimal bAmt = bAmtObj != null && bAmtObj != DBNull.Value ? Convert.ToDecimal(bAmtObj) : request.AppAmt;

                // 3. Insert Advance Record into POADVANCEMST
                const string insertSql = @"
                    INSERT INTO POADVANCEMST (
                        PO_No, App_dt, App_Amt, App_less, App_LOC, App_Edate, 
                        APP_UsrName, App_EMode, App_BAmt, App_Remark, App_MDate, App_MID, APP_LOCMODE, TypeID
                    ) 
                    VALUES (
                        @PoNo, @AppDt, @AppAmt, @AppLess, @AppLoc, GETDATE(), 
                        @UsrName, @AppEMode, @BAmt, @Remark, @MDate, @PartyId, @AppLocMode, 0
                    );
                    SELECT CAST(SCOPE_IDENTITY() AS INT);";

                var mDate = request.AppMDate ?? request.AppDt;
                var mode = !string.IsNullOrWhiteSpace(request.AppEMode) ? request.AppEMode.Trim() : "Cheque";
                var locMode = !string.IsNullOrWhiteSpace(request.ChequeNo) 
                    ? request.ChequeNo.Trim() 
                    : (!string.IsNullOrWhiteSpace(request.BankName) ? request.BankName.Trim() : "");

                var remark = request.AppRemark?.Trim() ?? "";
                if (!string.IsNullOrWhiteSpace(request.BankName) && !remark.Contains(request.BankName.Trim(), StringComparison.OrdinalIgnoreCase))
                {
                    remark = string.IsNullOrWhiteSpace(remark) 
                        ? $"Bank: {request.BankName.Trim()}" 
                        : $"{remark} (Bank: {request.BankName.Trim()})";
                }

                var newPoId = await conn.ExecuteScalarAsync<int>(insertSql, new
                {
                    PoNo = request.PoNo.Trim(),
                    AppDt = request.AppDt.Date,
                    AppAmt = request.AppAmt,
                    AppLess = request.AppLess,
                    AppLoc = _databaseLocation,
                    UsrName = !string.IsNullOrWhiteSpace(username) ? username.Trim() : "ADMIN",
                    AppEMode = mode,
                    BAmt = bAmt,
                    Remark = remark,
                    MDate = mDate.Date,
                    PartyId = request.PartyId,
                    AppLocMode = locMode
                }, tx);

                tx.Commit();
                return newPoId;
            }
            catch
            {
                tx.Rollback();
                throw;
            }
        }

        public async Task<bool> DeleteAdvanceAsync(int poId)
        {
            using var conn = CreateConnection();
            await conn.OpenAsync();
            using var tx = conn.BeginTransaction();

            try
            {
                // Verify lock date of existing record
                const string checkSql = "SELECT APP_DT FROM POADVANCEMST WHERE PO_ID = @PoId;";
                var appDtObj = await conn.ExecuteScalarAsync<object?>(checkSql, new { PoId = poId }, tx);
                if (appDtObj != null && appDtObj != DBNull.Value)
                {
                    var dt = Convert.ToDateTime(appDtObj).Date;
                    const string lockSql = "SELECT COUNT(1) FROM LOCKDATAMST WHERE @TargetDate = LDM_STDT;";
                    var lockCount = await conn.ExecuteScalarAsync<int>(lockSql, new { TargetDate = dt }, tx);
                    if (lockCount > 0)
                    {
                        throw new InvalidOperationException($"Cannot delete advance record: Transactions for date {dt:yyyy-MM-dd} are locked in LOCKDATAMST.");
                    }
                }

                const string deleteSql = "DELETE FROM POADVANCEMST WHERE PO_ID = @PoId;";
                var rows = await conn.ExecuteAsync(deleteSql, new { PoId = poId }, tx);
                tx.Commit();
                return rows > 0;
            }
            catch
            {
                tx.Rollback();
                throw;
            }
        }
    }
}
