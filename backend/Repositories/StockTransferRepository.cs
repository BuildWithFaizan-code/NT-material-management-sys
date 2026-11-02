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
    public class StockTransferRepository : IStockTransferRepository
    {
        private readonly string _connectionString;
        private readonly ILogger<StockTransferRepository> _logger;

        public StockTransferRepository(IConfiguration configuration, ILogger<StockTransferRepository> logger)
        {
            _connectionString = DbConnectionHelper.ResolveConnectionString(configuration);
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        private SqlConnection CreateConnection() => new(_connectionString);

        private static string GetPrefixForMode(string? issueMode)
        {
            if (string.IsNullOrWhiteSpace(issueMode)) return "STRF";
            var trimmed = issueMode.Trim();
            if (trimmed.Equals("To Department", StringComparison.OrdinalIgnoreCase)) return "REGU";
            if (trimmed.Equals("To WIP", StringComparison.OrdinalIgnoreCase)) return "REGU";
            return "STRF";
        }

        private static (DateTime FyStart, DateTime FyEnd, int FySuffix) GetFinancialYearBounds(DateTime date)
        {
            if (date.Month >= 4)
            {
                return (
                    new DateTime(date.Year, 4, 1),
                    new DateTime(date.Year + 1, 3, 31, 23, 59, 59),
                    (date.Year + 1) % 100
                );
            }
            return (
                new DateTime(date.Year - 1, 4, 1),
                new DateTime(date.Year, 3, 31, 23, 59, 59),
                date.Year % 100
            );
        }

        public async Task<string> GetNextIssueCodePreviewAsync(DateTime date, string issueMode)
        {
            using var conn = CreateConnection();
            return await GetNextIssueCodePreviewInternalAsync(conn, date, issueMode);
        }

        private static async Task<string> GetNextIssueCodePreviewInternalAsync(
            IDbConnection conn, DateTime date, string issueMode, IDbTransaction? trans = null)
        {
            var prefix = GetPrefixForMode(issueMode);
            var (fyStart, fyEnd, fySuffix) = GetFinancialYearBounds(date);

            const string sqlSeq = @"
                SELECT ISNULL(MAX(DBO.VAL(SUBSTRING(ISSUECODE, 6, 6))), 0)
                FROM ISSUEMST
                WHERE LEFT(ISSUECODE, 4) = @Prefix 
                  AND ISSUEDATE >= @FyStart AND ISSUEDATE <= @FyEnd";

            var maxSeq = await conn.ExecuteScalarAsync<int>(sqlSeq, new { Prefix = prefix, FyStart = fyStart, FyEnd = fyEnd }, trans);
            var newSeq = maxSeq + 1;
            return $"{prefix}/{newSeq:D6}/{fySuffix:D2}";
        }

        public async Task<StockTransferLookupsDto> GetLookupsAsync(int? fromStoreId)
        {
            var lookups = new StockTransferLookupsDto();
            using var conn = CreateConnection();

            // 1. Departments (LABOURMST)
            const string sqlDepts = @"
                SELECT LAB_CODE AS Id, CAST(LAB_CODE AS NVARCHAR(50)) AS Code, LAB_NAME AS Name 
                FROM LABOURMST 
                WHERE (LAB_STATUS = '' OR LAB_STATUS IS NULL OR LAB_STATUS = 'YES') 
                ORDER BY LAB_NAME";
            lookups.Departments = (await conn.QueryAsync<StockTransferLookupItemDto>(sqlDepts)).ToList();

            // 2. Stores (STOREMST)
            const string sqlStores = @"
                SELECT STR_CODE AS Id, CAST(STR_CODE AS NVARCHAR(50)) AS Code, STR_NAME AS Name 
                FROM STOREMST 
                WHERE STR_NAME <> '' 
                ORDER BY STR_NAME";
            lookups.Stores = (await conn.QueryAsync<StockTransferLookupItemDto>(sqlStores)).ToList();

            // 3. Divisions / Cost Centers (KHATAMST)
            const string sqlDivs = @"
                SELECT KH_CODE AS Id, CAST(KH_CODE AS NVARCHAR(50)) AS Code, KH_NAME AS Name 
                FROM KHATAMST 
                CROSS APPLY DBO.FNSPLITSTRING(KH_BRANCH, ',') 
                WHERE KH_NAME <> '' 
                  AND (KH_DISPLAY IS NULL OR KH_DISPLAY = 0) 
                  AND SPLITDATA = '1' 
                ORDER BY KH_NAME";
            lookups.Divisions = (await conn.QueryAsync<StockTransferLookupItemDto>(sqlDivs)).ToList();

            // 4. Plants (PKDEP)
            const string sqlPlants = @"
                SELECT PDEP_CODE AS Id, CAST(PDEP_CODE AS NVARCHAR(50)) AS Code, PDEP_NAME AS Name 
                FROM PKDEP 
                ORDER BY PDEP_NAME";
            lookups.Plants = (await conn.QueryAsync<StockTransferLookupItemDto>(sqlPlants)).ToList();

            // 5. Issue Modes (Queried dynamically from ISSUEMST)
            const string sqlModes = @"
                SELECT DISTINCT RTRIM(LTRIM(IssueMode)) AS Name 
                FROM ISSUEMST 
                WHERE IssueMode IS NOT NULL AND RTRIM(LTRIM(IssueMode)) <> '' 
                ORDER BY Name";
            var modes = (await conn.QueryAsync<string>(sqlModes))
                .Where(m => !string.IsNullOrWhiteSpace(m))
                .ToList();

            if (!modes.Contains("Stock Transfer", StringComparer.OrdinalIgnoreCase))
            {
                modes.Insert(0, "Stock Transfer");
            }
            if (!modes.Contains("To Department", StringComparer.OrdinalIgnoreCase))
            {
                modes.Add("To Department");
            }
            if (!modes.Contains("To WIP", StringComparer.OrdinalIgnoreCase))
            {
                modes.Add("To WIP");
            }
            lookups.IssueModes = modes;

            // Generate initial next document number preview
            lookups.NextDocNo = await GetNextIssueCodePreviewInternalAsync(conn, DateTime.Today, "Stock Transfer");

            return lookups;
        }

        public async Task<List<StockTransferLookupItemDto>> GetToStoresAsync(int fromStoreId)
        {
            using var conn = CreateConnection();

            // Find stores sharing the same GSTIN (BUSYMST.BY_ADD2) as the source store
            const string sql = @"
                SELECT DISTINCT SM.STR_CODE AS Id, CAST(SM.STR_CODE AS NVARCHAR(50)) AS Code, SM.STR_NAME AS Name
                FROM STOREMST AS SM
                WHERE SM.STR_NAME <> '' 
                  AND SM.STR_CODE IN (
                      SELECT BY_CODE FROM BUSYMST 
                      WHERE BY_ADD2 = (SELECT BY_ADD2 FROM BUSYMST WHERE BY_CODE = @FromStoreId)
                  )
                ORDER BY SM.STR_NAME";

            var result = (await conn.QueryAsync<StockTransferLookupItemDto>(sql, new { FromStoreId = fromStoreId })).ToList();

            // Fallback to all stores if no GSTIN match was found
            if (result.Count == 0)
            {
                const string sqlFallback = @"
                    SELECT STR_CODE AS Id, CAST(STR_CODE AS NVARCHAR(50)) AS Code, STR_NAME AS Name 
                    FROM STOREMST 
                    WHERE STR_NAME <> '' 
                    ORDER BY STR_NAME";
                result = (await conn.QueryAsync<StockTransferLookupItemDto>(sqlFallback)).ToList();
            }

            return result;
        }

        public async Task<StockCatalogPagedResultDto> GetStockCatalogAsync(
            DateTime date, int sourceDept, int sourceStore, int sourceDiv, string? searchQuery, int page, int pageSize)
        {
            using var conn = CreateConnection();

            var safePage = page < 1 ? 1 : page;
            var safePageSize = pageSize < 1 ? 50 : (pageSize > 200 ? 200 : pageSize);
            var offset = (safePage - 1) * safePageSize;

            const string sql = @"
                SELECT 
                    IM.I_CODE AS ItemCode,
                    IM.I_NAME1 AS ItemName,
                    ISNULL(R.MRGNO, '') AS MrgNo,
                    ISNULL(R.MAT_GRADE, '') AS Grade,
                    ISNULL(R.MAT_SHADE, '') AS Shade,
                    ISNULL(MAX(IMR_MAKER), '') AS Maker,
                    ISNULL(UM.UNIT_CODE, 0) AS UnitCode,
                    ISNULL(UM.UNIT_NAME, '') AS UnitName,
                    SUM(STKPCS) AS Pcs,
                    ROUND(SUM(AMT) / CASE WHEN ROUND(SUM(R.I_QTY), 3) = 0 THEN 1 ELSE ROUND(SUM(R.I_QTY), 3) END, 3) AS Rate,
                    ROUND(SUM(R.I_QTY), 3) AS Stock,
                    ISNULL(I_BLOCK, '') AS IBlock,
                    ISNULL(SIM_BIN, '') AS SimBin,
                    SUM(STKCOPS) AS Meter,
                    ISNULL(R.MAT_OTHER, '') AS MatType
                FROM ITEMMST AS IM 
                LEFT OUTER JOIN CATEGORYMST AS CM ON CM.CAT_CODE = IM.I_CID 
                LEFT JOIN STOCKREGNEW AS R ON R.I_CODE = IM.I_CODE 
                LEFT JOIN UNITMST AS UM ON R.MAT_UNIT = UM.UNIT_CODE 
                LEFT JOIN SUBITEMMST AS D ON IM.I_CODE = D.SIM_CODE 
                LEFT JOIN ITEMMARGE AS Y ON (R.MRGNO = Y.IMR_MRGNO) AND (IM.I_CODE = Y.I_CODE) 
                LEFT JOIN PARTYMST AS PM ON R.PR_ID = PM.P_CODE  
                LEFT JOIN SKUMST AS Z ON IM.I_CODE = Z.SKU_CODE 
                WHERE R.SR_STK = 'Y'   
                  AND R.DT <= @Date
                  AND (@SourceStore = 0 OR R.STORE_ID = @SourceStore)
                  AND (@SourceDiv = 0 OR (R.KH_CODE = @SourceDiv AND R.STK_DIVID = @SourceDiv))
                  AND (@Search IS NULL OR @Search = '' OR IM.I_CODE LIKE '%' + @Search + '%' OR IM.I_NAME1 LIKE '%' + @Search + '%')
                GROUP BY 
                    IM.I_NAME1, IM.I_CODE, UM.UNIT_CODE, UM.UNIT_NAME, I_BLOCK, I_PNET, SIM_BIN, 
                    R.MRGNO, R.MAT_GRADE, R.MAT_SHADE, R.MAT_OTHER  
                HAVING ROUND(SUM(R.I_QTY), 3) <> 0
                ORDER BY IM.I_NAME1
                OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY";

            const string sqlCount = @"
                SELECT COUNT(1) FROM (
                    SELECT IM.I_CODE
                    FROM ITEMMST AS IM 
                    LEFT JOIN STOCKREGNEW AS R ON R.I_CODE = IM.I_CODE 
                    WHERE R.SR_STK = 'Y'   
                      AND R.DT <= @Date
                      AND (@SourceStore = 0 OR R.STORE_ID = @SourceStore)
                      AND (@SourceDiv = 0 OR (R.KH_CODE = @SourceDiv AND R.STK_DIVID = @SourceDiv))
                      AND (@Search IS NULL OR @Search = '' OR IM.I_CODE LIKE '%' + @Search + '%' OR IM.I_NAME1 LIKE '%' + @Search + '%')
                    GROUP BY IM.I_NAME1, IM.I_CODE, R.MRGNO, R.MAT_GRADE, R.MAT_SHADE, R.MAT_OTHER  
                    HAVING ROUND(SUM(R.I_QTY), 3) <> 0
                ) AS SubQuery";

            var items = (await conn.QueryAsync<StockCatalogItemDto>(sql, new
            {
                Date = date.Date,
                SourceDiv = sourceDiv,
                SourceStore = sourceStore,
                Search = string.IsNullOrWhiteSpace(searchQuery) ? null : searchQuery.Trim(),
                Offset = offset,
                PageSize = safePageSize
            })).ToList();

            var totalCount = await conn.ExecuteScalarAsync<int>(sqlCount, new
            {
                Date = date.Date,
                SourceDiv = sourceDiv,
                SourceStore = sourceStore,
                Search = string.IsNullOrWhiteSpace(searchQuery) ? null : searchQuery.Trim()
            });

            return new StockCatalogPagedResultDto
            {
                Items = items,
                TotalCount = totalCount
            };
        }

        public async Task<double> CheckStockAvailabilityAsync(
            DateTime date, string currentDocNo, string itemCode, string mrgNo, string grade, string shade, 
            int sourceDept, int sourceStore, int sourceDiv, int uom)
        {
            using var conn = CreateConnection();

            const string sql = @"
                SELECT ISNULL(SUM(I_QTY), 0) AS STK 
                FROM STOCKREGNEW AS S 
                WHERE S.SR_STK = 'Y'  
                  AND DT <= @Date 
                  AND SR_CODE <> @CurrentDocNo 
                  AND I_CODE = @ItemCode
                  AND ISNULL(MRGNO, '') = @MrgNo
                  AND ISNULL(MAT_GRADE, '') = @Grade
                  AND ISNULL(MAT_SHADE, '') = @Shade
                  AND KH_CODE = @SourceDiv 
                  AND STORE_ID = @SourceStore 
                  AND STK_DIVID = @SourceDiv 
                  AND MAT_UNIT = @Uom";

            var stock = await conn.ExecuteScalarAsync<double?>(sql, new
            {
                Date = date.Date,
                CurrentDocNo = currentDocNo ?? string.Empty,
                ItemCode = itemCode,
                MrgNo = mrgNo ?? string.Empty,
                Grade = grade ?? string.Empty,
                Shade = shade ?? string.Empty,
                SourceDiv = sourceDiv,
                SourceStore = sourceStore,
                Uom = uom
            });

            return stock ?? 0.0;
        }

        public async Task<bool> IsDateLockedAsync(DateTime date)
        {
            using var conn = CreateConnection();
            const string sql = "SELECT COUNT(1) FROM LOCKDATAMST WHERE LDM_STDT = @Date";
            var count = await conn.ExecuteScalarAsync<int>(sql, new { Date = date.Date });
            return count > 0;
        }

        public async Task<List<string>> GetRemarkSuggestionsAsync(string query)
        {
            using var conn = CreateConnection();
            const string sql = @"
                SELECT TOP 10 REMARK 
                FROM ISSUEMST 
                WHERE REMARK IS NOT NULL AND REMARK <> ''
                  AND (@Query IS NULL OR @Query = '' OR REMARK LIKE '%' + @Query + '%')
                GROUP BY REMARK 
                ORDER BY REMARK";

            var list = (await conn.QueryAsync<string>(sql, new { Query = string.IsNullOrWhiteSpace(query) ? null : query.Trim() })).ToList();
            return list;
        }

        public async Task<List<PendingRequisitionItemDto>> GetPendingRequisitionsAsync(string? search)
        {
            using var conn = CreateConnection();
            const string sql = @"
                SELECT TOP 150 
                    RD.Req_Code AS ReqCode,
                    RM.Req_Date AS ReqDate,
                    RD.Item_Code AS ItemCode,
                    ISNULL(IM.I_NAME1, '') AS ItemName,
                    ISNULL(RD.Req_UOM, ISNULL(IM.I_UOM, 0)) AS Uom,
                    ISNULL(UM.UNIT_NAME, '') AS UnitName,
                    ISNULL(RD.Req_Qty, 0) AS ReqQty,
                    ISNULL(RD.Bal_Qty, 0) AS BalQty,
                    ISNULL(RD.Rate, 0) AS Rate,
                    ISNULL(RD.Req_MrgNo, '') AS MrgNo,
                    ISNULL(RD.Req_Grade, '') AS Grade,
                    ISNULL(RD.Req_Shade, '') AS Shade
                FROM REQUISITION_DET AS RD
                INNER JOIN REQUISITION_MASTER AS RM ON RM.Req_Code = RD.Req_Code
                LEFT JOIN ITEMMST AS IM ON IM.I_CODE = RD.Item_Code
                LEFT JOIN UNITMST AS UM ON UM.UNIT_CODE = ISNULL(RD.Req_UOM, IM.I_UOM)
                WHERE (RD.Bal_Qty > 0 OR RD.Bal_Qty IS NULL)
                  AND (@Search IS NULL OR @Search = '' 
                       OR RD.Req_Code LIKE '%' + @Search + '%' 
                       OR RD.Item_Code LIKE '%' + @Search + '%' 
                       OR IM.I_NAME1 LIKE '%' + @Search + '%')
                ORDER BY RM.Req_Date DESC, RD.Req_Code DESC";

            var list = (await conn.QueryAsync<PendingRequisitionItemDto>(sql, new
            {
                Search = string.IsNullOrWhiteSpace(search) ? null : search.Trim()
            })).ToList();

            return list;
        }

        public async Task<StockTransferPagedListDto> GetTransfersAsync(
            DateTime? fromDate, DateTime? toDate, string? searchQuery, string? issueMode, int page, int pageSize)
        {
            using var conn = CreateConnection();

            var safePage = page < 1 ? 1 : page;
            var safePageSize = pageSize < 1 ? 25 : (pageSize > 150 ? 150 : pageSize);
            var offset = (safePage - 1) * safePageSize;

            const string sqlCount = @"
                SELECT COUNT(1) 
                FROM ISSUEMST AS IM
                LEFT JOIN STOREMST AS SM ON SM.STR_CODE = IM.Str_Code
                LEFT JOIN LABOURMST AS LM ON LM.LAB_CODE = IM.Issue_To
                WHERE (@IssueMode IS NULL OR @IssueMode = '' OR IM.IssueMode = @IssueMode)
                  AND (@FromDate IS NULL OR IM.IssueDate >= @FromDate)
                  AND (@ToDate IS NULL OR IM.IssueDate <= @ToDate)
                  AND (@SearchQuery IS NULL OR @SearchQuery = '' 
                       OR IM.IssueCode LIKE '%' + @SearchQuery + '%' 
                       OR IM.REMARK LIKE '%' + @SearchQuery + '%' 
                       OR IM.Iss_MacNo LIKE '%' + @SearchQuery + '%' 
                       OR SM.STR_NAME LIKE '%' + @SearchQuery + '%' 
                       OR LM.LAB_NAME LIKE '%' + @SearchQuery + '%')";

            var totalCount = await conn.ExecuteScalarAsync<int>(sqlCount, new
            {
                IssueMode = string.IsNullOrWhiteSpace(issueMode) ? null : issueMode.Trim(),
                FromDate = fromDate?.Date,
                ToDate = toDate?.Date,
                SearchQuery = string.IsNullOrWhiteSpace(searchQuery) ? null : searchQuery.Trim()
            });

            const string sqlData = @"
                SELECT 
                    IM.IssueCode,
                    IM.IssueDate,
                    IM.IssueMode,
                    ISNULL(IM.IssueSource, 'Direct') AS IssueSource,
                    ISNULL(IM.Str_Code, 0) AS SourceStoreId,
                    ISNULL(SM.STR_NAME, '') AS SourceStoreName,
                    ISNULL(IM.Issue_To, 0) AS SourceDeptCode,
                    ISNULL(LM.LAB_NAME, '') AS SourceDeptName,
                    ISNULL((SELECT TOP 1 kh_code FROM ISSUEDET WHERE IssueCode = IM.IssueCode), 0) AS SourceDivId,
                    ISNULL(IM.Iss_MacNo, '') AS PlantName,
                    ISNULL(IM.Iss_Spin, '') AS Spindal,
                    ISNULL(IM.Iss_SlipNo, 0) AS SlipNo,
                    ISNULL(IM.Iss_JobCard, '') AS JobCard,
                    ISNULL(IM.Iss_VhNo, '') AS VehicleNo,
                    ISNULL(IM.Iss_Eway_Bill_No, '') AS EwayBillNo,
                    ISNULL(IM.TotQty, 0) AS TotQty,
                    ISNULL(IM.TotItm, 0) AS TotItm,
                    ISNULL(IM.TotPcs, 0) AS TotPcs,
                    ISNULL(IM.REMARK, '') AS Remark,
                    ISNULL(IM.Iss_UsrName, '') AS CreatedBy,
                    IM.Iss_EDate AS CreatedDate
                FROM ISSUEMST AS IM
                LEFT JOIN STOREMST AS SM ON SM.STR_CODE = IM.Str_Code
                LEFT JOIN LABOURMST AS LM ON LM.LAB_CODE = IM.Issue_To
                WHERE (@IssueMode IS NULL OR @IssueMode = '' OR IM.IssueMode = @IssueMode)
                  AND (@FromDate IS NULL OR IM.IssueDate >= @FromDate)
                  AND (@ToDate IS NULL OR IM.IssueDate <= @ToDate)
                  AND (@SearchQuery IS NULL OR @SearchQuery = '' 
                       OR IM.IssueCode LIKE '%' + @SearchQuery + '%' 
                       OR IM.REMARK LIKE '%' + @SearchQuery + '%' 
                       OR IM.Iss_MacNo LIKE '%' + @SearchQuery + '%' 
                       OR SM.STR_NAME LIKE '%' + @SearchQuery + '%' 
                       OR LM.LAB_NAME LIKE '%' + @SearchQuery + '%')
                ORDER BY IM.IssueDate DESC, IM.IssueCode DESC
                OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY";

            var records = (await conn.QueryAsync<StockTransferGridRecordDto>(sqlData, new
            {
                IssueMode = string.IsNullOrWhiteSpace(issueMode) ? null : issueMode.Trim(),
                FromDate = fromDate?.Date,
                ToDate = toDate?.Date,
                SearchQuery = string.IsNullOrWhiteSpace(searchQuery) ? null : searchQuery.Trim(),
                Offset = offset,
                PageSize = pageSize
            })).ToList();

            return new StockTransferPagedListDto
            {
                Records = records,
                TotalCount = totalCount
            };
        }

        public async Task<StockTransferDetailDto?> GetTransferByCodeAsync(string issueCode)
        {
            using var conn = CreateConnection();

            const string sqlHeader = @"
                SELECT 
                    IM.IssueCode,
                    IM.IssueDate,
                    IM.IssueMode,
                    ISNULL(IM.IssueSource, 'Direct') AS IssueSource,
                    ISNULL(IM.Str_Code, 0) AS SourceStoreId,
                    ISNULL(SM.STR_NAME, '') AS SourceStoreName,
                    ISNULL(IM.Issue_To, 0) AS SourceDeptCode,
                    ISNULL(LM.LAB_NAME, '') AS SourceDeptName,
                    ISNULL((SELECT TOP 1 kh_code FROM ISSUEDET WHERE IssueCode = IM.IssueCode), 0) AS SourceDivId,
                    ISNULL(IM.Iss_MacNo, '') AS PlantName,
                    ISNULL(IM.Iss_Spin, '') AS Spindal,
                    ISNULL(IM.Iss_SlipNo, 0) AS SlipNo,
                    ISNULL(IM.Iss_JobCard, '') AS JobCard,
                    ISNULL(IM.Iss_VhNo, '') AS VehicleNo,
                    ISNULL(IM.Iss_Eway_Bill_No, '') AS EwayBillNo,
                    ISNULL(IM.TotQty, 0) AS TotQty,
                    ISNULL(IM.TotItm, 0) AS TotItm,
                    ISNULL(IM.TotPcs, 0) AS TotPcs,
                    ISNULL(IM.REMARK, '') AS Remark,
                    ISNULL(IM.Iss_UsrName, '') AS CreatedBy,
                    IM.Iss_EDate AS CreatedDate
                FROM ISSUEMST AS IM
                LEFT JOIN STOREMST AS SM ON SM.STR_CODE = IM.Str_Code
                LEFT JOIN LABOURMST AS LM ON LM.LAB_CODE = IM.Issue_To
                WHERE IM.IssueCode = @IssueCode";

            var header = await conn.QueryFirstOrDefaultAsync<StockTransferGridRecordDto>(sqlHeader, new { IssueCode = issueCode });
            if (header == null) return null;

            const string sqlLines = @"
                SELECT 
                    ID.Iss_SrNo AS SrNo,
                    ISNULL(ID.Req_Code, 'None') AS ReqCode,
                    ISNULL(ID.ReqQty, 0) AS ReqQty,
                    ID.I_Code AS ItemCode,
                    ISNULL(IM.I_NAME1, '') AS ItemName,
                    ISNULL(ID.Dept_code, 0) AS ToDeptCode,
                    ISNULL(LM.LAB_NAME, '') AS ToDeptName,
                    ISNULL(ID.Rec_StoreID, 0) AS ToStoreId,
                    ISNULL(SM.STR_NAME, '') AS ToStoreName,
                    ISNULL(ID.Rec_CostID, 0) AS ToCostId,
                    ISNULL(KM.KH_NAME, '') AS ToCostName,
                    ISNULL(ID.UOM, 0) AS Uom,
                    ISNULL(UM.UNIT_NAME, '') AS UnitName,
                    ISNULL(ID.MrgNo, '') AS MrgNo,
                    ISNULL(ID.Mat_Grade, '') AS Grade,
                    ISNULL(ID.Mat_Shade, '') AS Shade,
                    ISNULL(ID.Mat_Maker, '') AS Maker,
                    ISNULL(ID.Rate, 0) AS Rate,
                    0 AS Stock,
                    ISNULL(ID.IssPcs, 0) AS IssPcs,
                    ISNULL(ID.IssueQty, 0) AS IssueQty,
                    ISNULL(ID.BinNo, '') AS BinNo,
                    ISNULL(ID.ISD_Remark, '') AS Remark
                FROM ISSUEDET AS ID
                LEFT JOIN ITEMMST AS IM ON IM.I_CODE = ID.I_Code
                LEFT JOIN UNITMST AS UM ON UM.UNIT_CODE = ID.UOM
                LEFT JOIN LABOURMST AS LM ON LM.LAB_CODE = ID.Dept_code
                LEFT JOIN STOREMST AS SM ON SM.STR_CODE = ID.Rec_StoreID
                LEFT JOIN KHATAMST AS KM ON KM.KH_CODE = ID.Rec_CostID
                WHERE ID.IssueCode = @IssueCode
                ORDER BY ID.Iss_SrNo";

            var lines = (await conn.QueryAsync<StockTransferLineInputDto>(sqlLines, new { IssueCode = issueCode })).ToList();

            return new StockTransferDetailDto
            {
                Header = header,
                Lines = lines
            };
        }

        public async Task<StockTransferSaveResultDto> CreateTransferAsync(
            StockTransferCreateRequestDto request, string username, string locationTag, string companyName)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.Lines == null || request.Lines.Count == 0)
                throw new InvalidOperationException("Stock transfer requires at least one line item.");

            using var conn = CreateConnection();
            await conn.OpenAsync();
            using var trans = conn.BeginTransaction(IsolationLevel.Serializable);

            try
            {
                // 1. Date Lock Enforcement
                const string sqlLock = "SELECT COUNT(1) FROM LOCKDATAMST WHERE LDM_STDT = @Date";
                var isLocked = (await conn.ExecuteScalarAsync<int>(sqlLock, new { Date = request.IssueDate.Date }, trans)) > 0;
                if (isLocked)
                {
                    throw new InvalidOperationException($"Transaction date {request.IssueDate:yyyy-MM-dd} is locked against financial changes.");
                }

                // 2. Financial Year derivation (April 1 to March 31)
                var prefix = GetPrefixForMode(request.IssueMode);
                var (fyStart, fyEnd, fySuffix) = GetFinancialYearBounds(request.IssueDate);

                // Sequence generation under UPDLOCK/HOLDLOCK
                const string sqlSeq = @"
                    SELECT ISNULL(MAX(DBO.VAL(SUBSTRING(ISSUECODE, 6, 6))), 0)
                    FROM ISSUEMST WITH (UPDLOCK, HOLDLOCK)
                    WHERE LEFT(ISSUECODE, 4) = @Prefix 
                      AND ISSUEDATE >= @FyStart AND ISSUEDATE <= @FyEnd";

                var maxSeq = await conn.ExecuteScalarAsync<int>(sqlSeq, new { Prefix = prefix, FyStart = fyStart, FyEnd = fyEnd }, trans);
                var newSeq = maxSeq + 1;
                var issueCode = $"{prefix}/{newSeq:D6}/{fySuffix:D2}";

                // Aggregate totals
                double totQty = request.Lines.Sum(l => l.IssueQty);
                int totItm = request.Lines.Count;
                double totPcs = request.Lines.Sum(l => l.IssPcs);

                var firstLine = request.Lines[0];

                // 3. DAYBOOK Row #1 (Item audit log)
                const string sqlDaybook1 = @"
                    INSERT INTO DAYBOOK (DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES (GETDATE(), @Username, @FirstItemName, @FirstItemQty, @DocNo, 'NEW', 'ISU', 1, @CompanyName)";

                await conn.ExecuteAsync(sqlDaybook1, new
                {
                    Username = username,
                    FirstItemName = string.IsNullOrWhiteSpace(firstLine.ItemName) ? firstLine.ItemCode : firstLine.ItemName,
                    FirstItemQty = firstLine.IssueQty,
                    DocNo = issueCode,
                    CompanyName = companyName
                }, trans);

                // 4. Insert Header into ISSUEMST
                const string sqlInsertHeader = @"
                    INSERT INTO IssueMst (
                        IssueCode, IssueDate, IssueMode, Issue_To, Str_Code, TotQty, TotItm, IssueSource, 
                        Iss_MacNo, Iss_Spin, Iss_Book, Iss_LOC, Iss_EDate, Iss_UsrName, Iss_EMode, 
                        Iss_SlipNo, Iss_JobCard, TypeID, Issu_Name, Co_No, remark, Iss_OperCode, 
                        Iss_Joint, Iss_Meters, Iss_AcTone, Iss_BoilYN, Iss_BoilTm, Iss_TapTaste, 
                        Iss_Shift, Prod_Qty, West_Qty, Ret_Qty, Stock_Qty, TotPcs,
                        Iss_VhNo, Iss_Eway_Bill_No
                    ) VALUES (
                        @IssueCode, @IssueDate, @IssueMode, @SourceDeptCode, @SourceStoreId, @TotQty, @TotItm, @IssueSource,
                        @PlantName, @Spindal, '', @LocationTag, GETDATE(), @Username, 'New',
                        @SlipNo, @JobCard, 0, '', 0, @Remark, 0,
                        0, 0, 0, 0, '1900-01-01 00:00:00', 0,
                        '', 0, 0, 0, 0, @TotPcs,
                        @VehicleNo, @EwayBillNo
                    )";

                await conn.ExecuteAsync(sqlInsertHeader, new
                {
                    IssueCode = issueCode,
                    IssueDate = request.IssueDate.Date,
                    IssueMode = string.IsNullOrWhiteSpace(request.IssueMode) ? "Stock Transfer" : request.IssueMode.Trim(),
                    SourceDeptCode = request.SourceDeptCode,
                    SourceStoreId = request.SourceStoreId,
                    TotQty = totQty,
                    TotItm = totItm,
                    IssueSource = string.IsNullOrWhiteSpace(request.IssueSource) ? "Direct" : request.IssueSource,
                    PlantName = request.PlantName ?? string.Empty,
                    Spindal = request.Spindal ?? string.Empty,
                    LocationTag = locationTag,
                    Username = username,
                    SlipNo = request.SlipNo,
                    JobCard = request.JobCard ?? string.Empty,
                    Remark = request.Remark ?? string.Empty,
                    TotPcs = totPcs,
                    VehicleNo = request.VehicleNo ?? string.Empty,
                    EwayBillNo = request.EwayBillNo ?? string.Empty
                }, trans);

                // 5. Insert Lines into ISSUEDET & Update ITEMMST
                const string sqlInsertLine = @"
                    INSERT INTO issuedet (
                        IssueCode, Iss_SrNo, I_Code, Rec_Itcode, UOM, Iss_Cut, Rate, ReqQty, IssueQty, IssPcs, 
                        kh_code, Req_Code, MrgNo, Mat_Grade, Mat_Shade, Mat_Maker, ISD_ConNo, ISD_Remark, 
                        Dept_code, Iss_DepCode, Iss_StoreID, Iss_SubCode, Rec_StoreID, binno, CUST_ID, 
                        cops, cops_type, Rec_CostID
                    ) VALUES (
                        @IssueCode, @SrNo, @ItemCode, '', @UOM, 0, @Rate, @ReqQty, @IssueQty, @IssPcs, 
                        @SourceDivId, @ReqCode, @MrgNo, @Grade, @Shade, @Maker, 0, @Remark, 
                        @ToDeptCode, @SourceDeptCode, @SourceStoreId, 0, @ToStoreId, @BinNo, 0, 
                        0, '', @ToCostId
                    )";

                const string sqlUpdateItem = @"
                    UPDATE ITEMMST 
                    SET I_RQTY = I_RQTY - @IssueQty, 
                        I_DEC = I_DEC - @DecValue 
                    WHERE I_CODE = @ItemCode";

                int sr = 1;
                foreach (var line in request.Lines)
                {
                    var reqCode = string.IsNullOrWhiteSpace(line.ReqCode) ? "None" : line.ReqCode;

                    await conn.ExecuteAsync(sqlInsertLine, new
                    {
                        IssueCode = issueCode,
                        SrNo = sr++,
                        ItemCode = line.ItemCode,
                        UOM = line.Uom,
                        Rate = line.Rate,
                        ReqQty = line.ReqQty,
                        IssueQty = line.IssueQty,
                        IssPcs = line.IssPcs,
                        SourceDivId = request.SourceDivId,
                        ReqCode = reqCode,
                        MrgNo = line.MrgNo ?? string.Empty,
                        Grade = line.Grade ?? string.Empty,
                        Shade = line.Shade ?? string.Empty,
                        Maker = line.Maker ?? string.Empty,
                        Remark = line.Remark ?? string.Empty,
                        ToDeptCode = line.ToDeptCode,
                        SourceDeptCode = request.SourceDeptCode,
                        SourceStoreId = request.SourceStoreId,
                        ToStoreId = line.ToStoreId,
                        BinNo = line.BinNo ?? string.Empty,
                        ToCostId = line.ToCostId
                    }, trans);

                    var decVal = Math.Round(line.IssueQty * line.Rate, 0);
                    await conn.ExecuteAsync(sqlUpdateItem, new
                    {
                        IssueQty = line.IssueQty,
                        DecValue = decVal,
                        ItemCode = line.ItemCode
                    }, trans);

                    if (!string.IsNullOrWhiteSpace(reqCode) && !reqCode.Equals("None", StringComparison.OrdinalIgnoreCase))
                    {
                        const string sqlUpdateReq = @"
                            UPDATE REQUISITION_DET 
                            SET Rec_Qty = ISNULL(Rec_Qty, 0) + @Qty,
                                Bal_Qty = CASE WHEN Bal_Qty - @Qty < 0 THEN 0 ELSE Bal_Qty - @Qty END
                            WHERE Req_Code = @ReqCode AND Item_Code = @ItemCode";
                        await conn.ExecuteAsync(sqlUpdateReq, new { Qty = line.IssueQty, ReqCode = reqCode, ItemCode = line.ItemCode }, trans);
                    }
                }

                // 6. Delete previous stock register records (standard safety in legacy trace)
                const string sqlDeleteStock = @"
                    DELETE FROM stockregnew 
                    WHERE sr_Code = @IssueCode AND mode IN ('Issue', 'Issue_Trf', 'IssueRet')";
                await conn.ExecuteAsync(sqlDeleteStock, new { IssueCode = issueCode }, trans);

                // 7. Outgoing Ledger Entry ('Issue')
                const string sqlStockOutgoing = @"
                    INSERT INTO stockregnew (
                        dt, I_Code, I_Qty, StkCops, StkPCs, MrgNo, Mat_Grade, Mat_Shade, Priority, 
                        SR_Code, P_Name, Amt, SR_Stk, Mode, kh_Code, store_id, TYPEID, SR_SRNO, 
                        PO_NO, PR_ID, mat_unit, mat_other, Stk_DivID
                    ) 
                    SELECT 
                        IssueDate AS Dt, I_Code, IssueQty * -1 AS Qty, Cops * -1, IssPcs * -1, mrgNo, Mat_Grade, Mat_Shade, 11 AS Priority, 
                        IM.IssueCode AS sr_Code, lm.lab_name AS P_Name, ROUND(rate * IssueQty * -1, 2) AS Amt, 'Y' AS sr_Stk, 'Issue', 
                        id.iss_depcode, id.iss_storeid, IM.TYPEID, ID.ISSUEID, 
                        IM.ISS_JOBCARD, id.CUST_ID, id.uom, id.cops_type, id.kh_code 
                    FROM IssueMst AS IM 
                    LEFT JOIN IssueDet AS ID ON IM.IssueCode = ID.IssueCode 
                    LEFT JOIN labourmst AS lm ON lm.lab_code = id.iss_depcode 
                    LEFT JOIN storemst AS sm ON sm.Str_Code = id.iss_storeid 
                    LEFT JOIN partymst AS pm ON id.cust_id = pm.p_code 
                    WHERE IM.IssueCode = @IssueCode AND IM.ISSUEDATE >= @FyStart";

                await conn.ExecuteAsync(sqlStockOutgoing, new { IssueCode = issueCode, FyStart = fyStart }, trans);

                // 8. Incoming Ledger Entry ('Issue_Trf')
                const string sqlStockIncoming = @"
                    INSERT INTO stockregnew (
                        dt, I_Code, I_Qty, StkCops, StkPcs, MrgNo, Mat_Grade, Mat_Shade, Priority, 
                        SR_Code, P_Name, Amt, SR_Stk, Mode, kh_Code, store_id, TYPEID, SR_SRNO, 
                        PO_NO, PR_ID, mat_unit, mat_other, Stk_DivID
                    ) 
                    SELECT 
                        IssueDate AS Dt, I_Code, IssueQty AS Qty, Cops, IssPcs, mrgNo, Mat_Grade, Mat_Shade, 11 AS Priority, 
                        IM.IssueCode AS sr_Code, lm.lab_name AS P_Name, ROUND(rate * IssueQty, 2) AS Amt, 'Y' AS sr_Stk, 'Issue_Trf', 
                        ID.DEPT_CODE, id.rec_storeid, im.co_no, ID.ISSUEID, 
                        IM.ISS_JOBCARD, id.CUST_ID, id.uom, id.cops_type, id.rec_costid 
                    FROM IssueMst AS IM 
                    LEFT JOIN IssueDet AS ID ON IM.IssueCode = ID.IssueCode 
                    LEFT JOIN labourmst AS lm ON lm.lab_code = id.iss_depcode 
                    LEFT JOIN storemst AS sm ON sm.Str_Code = id.iss_storeid 
                    LEFT JOIN partymst AS pm ON id.cust_id = pm.p_code 
                    WHERE IM.IssueCode = @IssueCode AND IM.ISSUEDATE >= @FyStart";

                await conn.ExecuteAsync(sqlStockIncoming, new { IssueCode = issueCode, FyStart = fyStart }, trans);

                // 9. DAYBOOK Row #2 (Confirmation audit log)
                const string sqlDeptName = "SELECT LAB_NAME FROM LABOURMST WHERE LAB_CODE = @DeptCode";
                var deptName = await conn.ExecuteScalarAsync<string>(sqlDeptName, new { DeptCode = request.SourceDeptCode }, trans) ?? "REGULAR";

                const string sqlDaybook2 = @"
                    INSERT INTO DAYBOOK (DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES (GETDATE(), @Username, @DeptName, @TotQty, @DocNo, 'NEW', 'ISU', 1, @CompanyName)";

                await conn.ExecuteAsync(sqlDaybook2, new
                {
                    Username = username,
                    DeptName = deptName,
                    TotQty = totQty,
                    DocNo = issueCode,
                    CompanyName = companyName
                }, trans);

                trans.Commit();

                return new StockTransferSaveResultDto
                {
                    IssueCode = issueCode,
                    Success = true,
                    Message = $"Stock transfer {issueCode} saved successfully."
                };
            }
            catch (Exception ex)
            {
                trans.Rollback();
                _logger.LogError(ex, "Failed to create Stock Transfer transaction.");
                throw;
            }
        }

        public async Task<StockTransferSaveResultDto> UpdateTransferAsync(
            string issueCode, StockTransferCreateRequestDto request, string username, string locationTag, string companyName)
        {
            if (string.IsNullOrWhiteSpace(issueCode)) throw new ArgumentException("Issue code is required.", nameof(issueCode));
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.Lines == null || request.Lines.Count == 0)
                throw new InvalidOperationException("Stock transfer requires at least one line item.");

            using var conn = CreateConnection();
            await conn.OpenAsync();
            using var trans = conn.BeginTransaction(IsolationLevel.Serializable);

            try
            {
                // 1. Fetch existing header to verify existence and check date locks
                const string sqlCheck = "SELECT IssueCode, IssueDate FROM ISSUEMST WITH (UPDLOCK, HOLDLOCK) WHERE IssueCode = @IssueCode";
                var existing = await conn.QueryFirstOrDefaultAsync<dynamic>(sqlCheck, new { IssueCode = issueCode }, trans);
                if (existing == null)
                    throw new KeyNotFoundException($"Stock transfer {issueCode} not found.");

                DateTime oldDate = existing.IssueDate;

                // Date Lock Verification (old date and new date)
                const string sqlLock = "SELECT COUNT(1) FROM LOCKDATAMST WHERE LDM_STDT = @Date";
                var isOldLocked = (await conn.ExecuteScalarAsync<int>(sqlLock, new { Date = oldDate.Date }, trans)) > 0;
                if (isOldLocked)
                    throw new InvalidOperationException($"Original transaction date {oldDate:yyyy-MM-dd} is locked.");

                var isNewLocked = (await conn.ExecuteScalarAsync<int>(sqlLock, new { Date = request.IssueDate.Date }, trans)) > 0;
                if (isNewLocked)
                    throw new InvalidOperationException($"New transaction date {request.IssueDate:yyyy-MM-dd} is locked.");

                // 2. Read existing lines from ISSUEDET to reverse previous stock and requisition adjustments
                const string sqlOldLines = "SELECT I_Code AS ItemCode, IssueQty, Rate, Req_Code AS ReqCode FROM ISSUEDET WHERE IssueCode = @IssueCode";
                var oldLines = (await conn.QueryAsync<dynamic>(sqlOldLines, new { IssueCode = issueCode }, trans)).ToList();

                // 3. Reverse prior stock balances in ITEMMST
                const string sqlRestoreItem = @"
                    UPDATE ITEMMST 
                    SET I_RQTY = I_RQTY + @IssueQty, 
                        I_DEC = I_DEC + @DecValue 
                    WHERE I_CODE = @ItemCode";

                foreach (var oldLine in oldLines)
                {
                    double oldQty = (double)oldLine.IssueQty;
                    double oldRate = (double)oldLine.Rate;
                    double oldDec = Math.Round(oldQty * oldRate, 0);
                    string oldItemCode = (string)oldLine.ItemCode;
                    string oldReqCode = (string)oldLine.ReqCode;

                    await conn.ExecuteAsync(sqlRestoreItem, new
                    {
                        IssueQty = oldQty,
                        DecValue = oldDec,
                        ItemCode = oldItemCode
                    }, trans);

                    if (!string.IsNullOrWhiteSpace(oldReqCode) && !oldReqCode.Equals("None", StringComparison.OrdinalIgnoreCase))
                    {
                        const string sqlRestoreReq = @"
                            UPDATE REQUISITION_DET 
                            SET Rec_Qty = CASE WHEN Rec_Qty - @Qty < 0 THEN 0 ELSE Rec_Qty - @Qty END,
                                Bal_Qty = Bal_Qty + @Qty
                            WHERE Req_Code = @ReqCode AND Item_Code = @ItemCode";
                        await conn.ExecuteAsync(sqlRestoreReq, new { Qty = oldQty, ReqCode = oldReqCode, ItemCode = oldItemCode }, trans);
                    }
                }

                // 4. Purge existing stock ledger rows in STOCKREGNEW
                const string sqlDeleteStock = @"
                    DELETE FROM stockregnew 
                    WHERE sr_Code = @IssueCode AND mode IN ('Issue', 'Issue_Trf', 'IssueRet')";
                await conn.ExecuteAsync(sqlDeleteStock, new { IssueCode = issueCode }, trans);

                // 5. Delete existing line items in ISSUEDET
                const string sqlDeleteLines = "DELETE FROM issuedet WHERE IssueCode = @IssueCode";
                await conn.ExecuteAsync(sqlDeleteLines, new { IssueCode = issueCode }, trans);

                // 6. Update master header in ISSUEMST
                double totQty = request.Lines.Sum(l => l.IssueQty);
                int totItm = request.Lines.Count;
                double totPcs = request.Lines.Sum(l => l.IssPcs);

                const string sqlUpdateHeader = @"
                    UPDATE IssueMst SET 
                        IssueDate = @IssueDate,
                        IssueMode = @IssueMode,
                        IssueSource = @IssueSource,
                        Issue_To = @SourceDeptCode,
                        Str_Code = @SourceStoreId,
                        TotQty = @TotQty,
                        TotItm = @TotItm,
                        TotPcs = @TotPcs,
                        Iss_MacNo = @PlantName,
                        Iss_Spin = @Spindal,
                        Iss_SlipNo = @SlipNo,
                        Iss_JobCard = @JobCard,
                        remark = @Remark,
                        Iss_VhNo = @VehicleNo,
                        Iss_Eway_Bill_No = @EwayBillNo,
                        Iss_UsrName = @Username,
                        Iss_EDate = GETDATE(),
                        Iss_EMode = 'Edit'
                    WHERE IssueCode = @IssueCode";

                await conn.ExecuteAsync(sqlUpdateHeader, new
                {
                    IssueCode = issueCode,
                    IssueDate = request.IssueDate.Date,
                    IssueMode = string.IsNullOrWhiteSpace(request.IssueMode) ? "Stock Transfer" : request.IssueMode.Trim(),
                    IssueSource = string.IsNullOrWhiteSpace(request.IssueSource) ? "Direct" : request.IssueSource,
                    SourceDeptCode = request.SourceDeptCode,
                    SourceStoreId = request.SourceStoreId,
                    TotQty = totQty,
                    TotItm = totItm,
                    TotPcs = totPcs,
                    PlantName = request.PlantName ?? string.Empty,
                    Spindal = request.Spindal ?? string.Empty,
                    SlipNo = request.SlipNo,
                    JobCard = request.JobCard ?? string.Empty,
                    Remark = request.Remark ?? string.Empty,
                    VehicleNo = request.VehicleNo ?? string.Empty,
                    EwayBillNo = request.EwayBillNo ?? string.Empty,
                    Username = username
                }, trans);

                // 7. Insert updated detail rows into ISSUEDET & update ITEMMST
                const string sqlInsertLine = @"
                    INSERT INTO issuedet (
                        IssueCode, Iss_SrNo, I_Code, Rec_Itcode, UOM, Iss_Cut, Rate, ReqQty, IssueQty, IssPcs, 
                        kh_code, Req_Code, MrgNo, Mat_Grade, Mat_Shade, Mat_Maker, ISD_ConNo, ISD_Remark, 
                        Dept_code, Iss_DepCode, Iss_StoreID, Iss_SubCode, Rec_StoreID, binno, CUST_ID, 
                        cops, cops_type, Rec_CostID
                    ) VALUES (
                        @IssueCode, @SrNo, @ItemCode, '', @UOM, 0, @Rate, @ReqQty, @IssueQty, @IssPcs, 
                        @SourceDivId, @ReqCode, @MrgNo, @Grade, @Shade, @Maker, 0, @Remark, 
                        @ToDeptCode, @SourceDeptCode, @SourceStoreId, 0, @ToStoreId, @BinNo, 0, 
                        0, '', @ToCostId
                    )";

                const string sqlDeductItem = @"
                    UPDATE ITEMMST 
                    SET I_RQTY = I_RQTY - @IssueQty, 
                        I_DEC = I_DEC - @DecValue 
                    WHERE I_CODE = @ItemCode";

                int sr = 1;
                foreach (var line in request.Lines)
                {
                    var reqCode = string.IsNullOrWhiteSpace(line.ReqCode) ? "None" : line.ReqCode;

                    await conn.ExecuteAsync(sqlInsertLine, new
                    {
                        IssueCode = issueCode,
                        SrNo = sr++,
                        ItemCode = line.ItemCode,
                        UOM = line.Uom,
                        Rate = line.Rate,
                        ReqQty = line.ReqQty,
                        IssueQty = line.IssueQty,
                        IssPcs = line.IssPcs,
                        SourceDivId = request.SourceDivId,
                        ReqCode = reqCode,
                        MrgNo = line.MrgNo ?? string.Empty,
                        Grade = line.Grade ?? string.Empty,
                        Shade = line.Shade ?? string.Empty,
                        Maker = line.Maker ?? string.Empty,
                        Remark = line.Remark ?? string.Empty,
                        ToDeptCode = line.ToDeptCode,
                        SourceDeptCode = request.SourceDeptCode,
                        SourceStoreId = request.SourceStoreId,
                        ToStoreId = line.ToStoreId,
                        BinNo = line.BinNo ?? string.Empty,
                        ToCostId = line.ToCostId
                    }, trans);

                    var decVal = Math.Round(line.IssueQty * line.Rate, 0);
                    await conn.ExecuteAsync(sqlDeductItem, new
                    {
                        IssueQty = line.IssueQty,
                        DecValue = decVal,
                        ItemCode = line.ItemCode
                    }, trans);

                    if (!string.IsNullOrWhiteSpace(reqCode) && !reqCode.Equals("None", StringComparison.OrdinalIgnoreCase))
                    {
                        const string sqlUpdateReq = @"
                            UPDATE REQUISITION_DET 
                            SET Rec_Qty = ISNULL(Rec_Qty, 0) + @Qty,
                                Bal_Qty = CASE WHEN Bal_Qty - @Qty < 0 THEN 0 ELSE Bal_Qty - @Qty END
                            WHERE Req_Code = @ReqCode AND Item_Code = @ItemCode";
                        await conn.ExecuteAsync(sqlUpdateReq, new { Qty = line.IssueQty, ReqCode = reqCode, ItemCode = line.ItemCode }, trans);
                    }
                }

                // 8. Re-insert outgoing and incoming rows into stockregnew
                DateTime fyStart = request.IssueDate.Month >= 4
                    ? new DateTime(request.IssueDate.Year, 4, 1)
                    : new DateTime(request.IssueDate.Year - 1, 4, 1);

                const string sqlStockOutgoing = @"
                    INSERT INTO stockregnew (
                        dt, I_Code, I_Qty, StkCops, StkPCs, MrgNo, Mat_Grade, Mat_Shade, Priority, 
                        SR_Code, P_Name, Amt, SR_Stk, Mode, kh_Code, store_id, TYPEID, SR_SRNO, 
                        PO_NO, PR_ID, mat_unit, mat_other, Stk_DivID
                    ) 
                    SELECT 
                        IssueDate AS Dt, I_Code, IssueQty * -1 AS Qty, Cops * -1, IssPcs * -1, mrgNo, Mat_Grade, Mat_Shade, 11 AS Priority, 
                        IM.IssueCode AS sr_Code, lm.lab_name AS P_Name, ROUND(rate * IssueQty * -1, 2) AS Amt, 'Y' AS sr_Stk, 'Issue', 
                        id.iss_depcode, id.iss_storeid, IM.TYPEID, ID.ISSUEID, 
                        IM.ISS_JOBCARD, id.CUST_ID, id.uom, id.cops_type, id.kh_code 
                    FROM IssueMst AS IM 
                    LEFT JOIN IssueDet AS ID ON IM.IssueCode = ID.IssueCode 
                    LEFT JOIN labourmst AS lm ON lm.lab_code = id.iss_depcode 
                    LEFT JOIN storemst AS sm ON sm.Str_Code = id.iss_storeid 
                    LEFT JOIN partymst AS pm ON id.cust_id = pm.p_code 
                    WHERE IM.IssueCode = @IssueCode AND IM.ISSUEDATE >= @FyStart";

                await conn.ExecuteAsync(sqlStockOutgoing, new { IssueCode = issueCode, FyStart = fyStart }, trans);

                const string sqlStockIncoming = @"
                    INSERT INTO stockregnew (
                        dt, I_Code, I_Qty, StkCops, StkPcs, MrgNo, Mat_Grade, Mat_Shade, Priority, 
                        SR_Code, P_Name, Amt, SR_Stk, Mode, kh_Code, store_id, TYPEID, SR_SRNO, 
                        PO_NO, PR_ID, mat_unit, mat_other, Stk_DivID
                    ) 
                    SELECT 
                        IssueDate AS Dt, I_Code, IssueQty AS Qty, Cops, IssPcs, mrgNo, Mat_Grade, Mat_Shade, 11 AS Priority, 
                        IM.IssueCode AS sr_Code, lm.lab_name AS P_Name, ROUND(rate * IssueQty, 2) AS Amt, 'Y' AS sr_Stk, 'Issue_Trf', 
                        ID.DEPT_CODE, id.rec_storeid, im.co_no, ID.ISSUEID, 
                        IM.ISS_JOBCARD, id.CUST_ID, id.uom, id.cops_type, id.rec_costid 
                    FROM IssueMst AS IM 
                    LEFT JOIN IssueDet AS ID ON IM.IssueCode = ID.IssueCode 
                    LEFT JOIN labourmst AS lm ON lm.lab_code = id.iss_depcode 
                    LEFT JOIN storemst AS sm ON sm.Str_Code = id.iss_storeid 
                    LEFT JOIN partymst AS pm ON id.cust_id = pm.p_code 
                    WHERE IM.IssueCode = @IssueCode AND IM.ISSUEDATE >= @FyStart";

                await conn.ExecuteAsync(sqlStockIncoming, new { IssueCode = issueCode, FyStart = fyStart }, trans);

                // 9. DAYBOOK Audit entry for EDIT
                const string sqlDaybook = @"
                    INSERT INTO DAYBOOK (DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES (GETDATE(), @Username, 'STOCK TRANSFER', @TotQty, @DocNo, 'EDIT', 'ISU', 1, @CompanyName)";

                await conn.ExecuteAsync(sqlDaybook, new
                {
                    Username = username,
                    TotQty = totQty,
                    DocNo = issueCode,
                    CompanyName = companyName
                }, trans);

                trans.Commit();

                return new StockTransferSaveResultDto
                {
                    IssueCode = issueCode,
                    Success = true,
                    Message = $"Stock transfer {issueCode} updated successfully."
                };
            }
            catch (Exception ex)
            {
                trans.Rollback();
                _logger.LogError(ex, "Failed to update Stock Transfer {IssueCode}.", issueCode);
                throw;
            }
        }

        public async Task<StockTransferSaveResultDto> DeleteTransferAsync(string issueCode, string username, string companyName)
        {
            if (string.IsNullOrWhiteSpace(issueCode)) throw new ArgumentException("Issue code is required.", nameof(issueCode));

            using var conn = CreateConnection();
            await conn.OpenAsync();
            using var trans = conn.BeginTransaction(IsolationLevel.Serializable);

            try
            {
                // 1. Fetch existing header
                const string sqlCheck = "SELECT IssueCode, IssueDate, TotQty FROM ISSUEMST WITH (UPDLOCK, HOLDLOCK) WHERE IssueCode = @IssueCode";
                var existing = await conn.QueryFirstOrDefaultAsync<dynamic>(sqlCheck, new { IssueCode = issueCode }, trans);
                if (existing == null)
                    throw new KeyNotFoundException($"Stock transfer {issueCode} not found.");

                DateTime issueDate = existing.IssueDate;
                double totQty = (double)(existing.TotQty ?? 0.0);

                // 2. Date Lock Verification
                const string sqlLock = "SELECT COUNT(1) FROM LOCKDATAMST WHERE LDM_STDT = @Date";
                var isLocked = (await conn.ExecuteScalarAsync<int>(sqlLock, new { Date = issueDate.Date }, trans)) > 0;
                if (isLocked)
                    throw new InvalidOperationException($"Transaction date {issueDate:yyyy-MM-dd} is locked against deletion.");

                // 3. Read lines to restore ITEMMST and Requisitions
                const string sqlLines = "SELECT I_Code AS ItemCode, IssueQty, Rate, Req_Code AS ReqCode FROM ISSUEDET WHERE IssueCode = @IssueCode";
                var lines = (await conn.QueryAsync<dynamic>(sqlLines, new { IssueCode = issueCode }, trans)).ToList();

                const string sqlRestoreItem = @"
                    UPDATE ITEMMST 
                    SET I_RQTY = I_RQTY + @IssueQty, 
                        I_DEC = I_DEC + @DecValue 
                    WHERE I_CODE = @ItemCode";

                foreach (var line in lines)
                {
                    double qty = (double)line.IssueQty;
                    double rate = (double)line.Rate;
                    double decVal = Math.Round(qty * rate, 0);
                    string itemCode = (string)line.ItemCode;
                    string reqCode = (string)line.ReqCode;

                    await conn.ExecuteAsync(sqlRestoreItem, new
                    {
                        IssueQty = qty,
                        DecValue = decVal,
                        ItemCode = itemCode
                    }, trans);

                    if (!string.IsNullOrWhiteSpace(reqCode) && !reqCode.Equals("None", StringComparison.OrdinalIgnoreCase))
                    {
                        const string sqlRestoreReq = @"
                            UPDATE REQUISITION_DET 
                            SET Rec_Qty = CASE WHEN Rec_Qty - @Qty < 0 THEN 0 ELSE Rec_Qty - @Qty END,
                                Bal_Qty = Bal_Qty + @Qty
                            WHERE Req_Code = @ReqCode AND Item_Code = @ItemCode";
                        await conn.ExecuteAsync(sqlRestoreReq, new { Qty = qty, ReqCode = reqCode, ItemCode = itemCode }, trans);
                    }
                }

                // 4. Purge STOCKREGNEW
                const string sqlDeleteStock = @"
                    DELETE FROM stockregnew 
                    WHERE sr_Code = @IssueCode AND mode IN ('Issue', 'Issue_Trf', 'IssueRet')";
                await conn.ExecuteAsync(sqlDeleteStock, new { IssueCode = issueCode }, trans);

                // 5. Delete ISSUEDET
                const string sqlDeleteLines = "DELETE FROM issuedet WHERE IssueCode = @IssueCode";
                await conn.ExecuteAsync(sqlDeleteLines, new { IssueCode = issueCode }, trans);

                // 6. Delete ISSUEMST
                const string sqlDeleteHeader = "DELETE FROM IssueMst WHERE IssueCode = @IssueCode";
                await conn.ExecuteAsync(sqlDeleteHeader, new { IssueCode = issueCode }, trans);

                // 7. DAYBOOK row for DELETE
                const string sqlDaybook = @"
                    INSERT INTO DAYBOOK (DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES (GETDATE(), @Username, 'STOCK TRANSFER', @TotQty, @DocNo, 'DELETE', 'ISU', 1, @CompanyName)";

                await conn.ExecuteAsync(sqlDaybook, new
                {
                    Username = username,
                    TotQty = totQty,
                    DocNo = issueCode,
                    CompanyName = companyName
                }, trans);

                trans.Commit();

                return new StockTransferSaveResultDto
                {
                    IssueCode = issueCode,
                    Success = true,
                    Message = $"Stock transfer {issueCode} deleted and inventory restored successfully."
                };
            }
            catch (Exception ex)
            {
                trans.Rollback();
                _logger.LogError(ex, "Failed to delete Stock Transfer {IssueCode}.", issueCode);
                throw;
            }
        }
    }
}
