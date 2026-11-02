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
    public class IssueManagerRepository : IIssueManagerRepository
    {
        private readonly string _connectionString;
        private readonly ILogger<IssueManagerRepository> _logger;

        public IssueManagerRepository(IConfiguration configuration, ILogger<IssueManagerRepository> logger)
        {
            _connectionString = DbConnectionHelper.ResolveConnectionString(configuration);
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        private SqlConnection CreateConnection() => new(_connectionString);

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

        public async Task<IssueManagerLookupsDto> GetLookupsAsync()
        {
            var lookups = new IssueManagerLookupsDto();
            using var conn = CreateConnection();

            // 1. Departments (LABOURMST)
            const string sqlDepts = @"
                SELECT LAB_CODE AS Id, CAST(LAB_CODE AS NVARCHAR(50)) AS Code, LAB_NAME AS Name 
                FROM LABOURMST 
                WHERE (LAB_STATUS = '' OR LAB_STATUS IS NULL OR LAB_STATUS = 'YES') 
                ORDER BY LAB_NAME";
            lookups.Departments = (await conn.QueryAsync<StockTransferLookupItemDto>(sqlDepts)).ToList();

            // 2. Stores / Plant (STOREMST)
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

            // 4. Machines (PKBASE) - Distinct list, excluding '*' since '*' is the 'None' option
            const string sqlMachines = @"
                SELECT DISTINCT RTRIM(LTRIM(PBASE_CODE)) AS PBASE_CODE 
                FROM PKBASE 
                WHERE PBASE_CODE IS NOT NULL AND RTRIM(LTRIM(PBASE_CODE)) <> '' AND RTRIM(LTRIM(PBASE_CODE)) <> '*'
                ORDER BY PBASE_CODE";
            lookups.Machines = (await conn.QueryAsync<string>(sqlMachines)).ToList();

            // 5. Issue Modes (6 full options per specification A9)
            lookups.IssueModes = new List<string>
            {
                "To Department",
                "To Store",
                "To Company",
                "To Dept (RGP)",
                "To WIP",
                "To Cost Center"
            };

            // 6. Sources (5 full options per specification A9)
            lookups.IssueSources = new List<string>
            {
                "Direct",
                "Requisition",
                "Job Card",
                "JobWork",
                "Packing"
            };

            return lookups;
        }

        public async Task<string> GetNextPreviewCodeAsync(DateTime date, string issueMode, string fromDeptName)
        {
            var prefix = IssuePrefixResolver.Resolve(issueMode, fromDeptName);
            var (fyStart, fyEnd, fySuffix) = GetFinancialYearBounds(date);

            using var conn = CreateConnection();
            const string sqlSeq = @"
                SELECT ISNULL(MAX(DBO.VAL(SUBSTRING(ISSUECODE, 6, 6))), 0)
                FROM ISSUEMST
                WHERE LEFT(ISSUECODE, 4) = @Prefix 
                  AND ISSUEDATE >= @FyStart AND ISSUEDATE <= @FyEnd";

            var maxSeq = await conn.ExecuteScalarAsync<int>(sqlSeq, new { Prefix = prefix, FyStart = fyStart, FyEnd = fyEnd });
            var newSeq = maxSeq + 1;
            return $"{prefix}/{newSeq:D6}/{fySuffix:D2}";
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

        public async Task<IssueManagerPagedListDto> GetIssuesAsync(
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
                WHERE IM.IssueMode <> 'Stock Transfer'
                  AND (@IssueMode IS NULL OR @IssueMode = '' OR IM.IssueMode = @IssueMode)
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
                    ISNULL(IM.Issue_To, 0) AS SourceDeptCode,
                    ISNULL(LM.LAB_NAME, '') AS SourceDeptName,
                    ISNULL(IM.Str_Code, 0) AS SourceStoreId,
                    ISNULL(SM.STR_NAME, '') AS SourceStoreName,
                    ISNULL((SELECT TOP 1 kh_code FROM ISSUEDET WHERE IssueCode = IM.IssueCode), 0) AS SourceDivId,
                    ISNULL(IM.Iss_MacNo, '') AS MachineNo,
                    ISNULL(IM.Iss_Spin, '') AS Spindal,
                    ISNULL(IM.Iss_SlipNo, 0) AS SlipNo,
                    ISNULL(IM.TotQty, 0) AS TotQty,
                    ISNULL(IM.TotItm, 0) AS TotItm,
                    ISNULL(IM.TotPcs, 0) AS TotPcs,
                    ISNULL(IM.REMARK, '') AS Remark,
                    ISNULL(IM.Iss_UsrName, '') AS CreatedBy,
                    IM.Iss_EDate AS CreatedDate
                FROM ISSUEMST AS IM
                LEFT JOIN STOREMST AS SM ON SM.STR_CODE = IM.Str_Code
                LEFT JOIN LABOURMST AS LM ON LM.LAB_CODE = IM.Issue_To
                WHERE IM.IssueMode <> 'Stock Transfer'
                  AND (@IssueMode IS NULL OR @IssueMode = '' OR IM.IssueMode = @IssueMode)
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

            var records = (await conn.QueryAsync<IssueManagerGridRecordDto>(sqlData, new
            {
                IssueMode = string.IsNullOrWhiteSpace(issueMode) ? null : issueMode.Trim(),
                FromDate = fromDate?.Date,
                ToDate = toDate?.Date,
                SearchQuery = string.IsNullOrWhiteSpace(searchQuery) ? null : searchQuery.Trim(),
                Offset = offset,
                PageSize = pageSize
            })).ToList();

            return new IssueManagerPagedListDto
            {
                Records = records,
                TotalCount = totalCount
            };
        }

        public async Task<IssueManagerDetailDto?> GetIssueByCodeAsync(string issueCode)
        {
            using var conn = CreateConnection();

            const string sqlHeader = @"
                SELECT 
                    IM.IssueCode,
                    IM.IssueDate,
                    IM.IssueMode,
                    ISNULL(IM.IssueSource, 'Direct') AS IssueSource,
                    ISNULL(IM.Issue_To, 0) AS SourceDeptCode,
                    ISNULL(LM.LAB_NAME, '') AS SourceDeptName,
                    ISNULL(IM.Str_Code, 0) AS SourceStoreId,
                    ISNULL(SM.STR_NAME, '') AS SourceStoreName,
                    ISNULL((SELECT TOP 1 kh_code FROM ISSUEDET WHERE IssueCode = IM.IssueCode), 0) AS SourceDivId,
                    ISNULL(IM.Iss_MacNo, '') AS MachineNo,
                    ISNULL(IM.Iss_Spin, '') AS Spindal,
                    ISNULL(IM.Iss_SlipNo, 0) AS SlipNo,
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

            var header = await conn.QueryFirstOrDefaultAsync<IssueManagerGridRecordDto>(sqlHeader, new { IssueCode = issueCode });
            if (header == null) return null;

            const string sqlLines = @"
                SELECT 
                    ID.Iss_SrNo AS SrNo,
                    ID.I_Code AS ItemCode,
                    ISNULL(IM.I_NAME1, '') AS ItemName,
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
                    ISNULL(ID.ISD_Remark, '') AS Remark
                FROM ISSUEDET AS ID
                LEFT JOIN ITEMMST AS IM ON IM.I_CODE = ID.I_Code
                LEFT JOIN UNITMST AS UM ON UM.UNIT_CODE = ID.UOM
                WHERE ID.IssueCode = @IssueCode
                ORDER BY ID.Iss_SrNo";

            var lines = (await conn.QueryAsync<IssueManagerLineInputDto>(sqlLines, new { IssueCode = issueCode })).ToList();

            return new IssueManagerDetailDto
            {
                Header = header,
                Lines = lines
            };
        }

        public async Task<IssueManagerSaveResultDto> CreateIssueAsync(
            IssueManagerCreateRequestDto request, string username, string locationTag, string companyName)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.Lines == null || request.Lines.Count == 0)
                throw new InvalidOperationException("Issue Manager requires at least one line item.");

            // Strict scope enforcement per prompt (SCOPE NOW)
            if (!string.Equals(request.IssueMode?.Trim(), "To Department", StringComparison.OrdinalIgnoreCase) ||
                !string.Equals(request.IssueSource?.Trim(), "Direct", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException(
                    "Currently, only Issue Mode 'To Department' with Source 'Direct' is available. Other modes and sources are awaiting specification (SCOPE NOW).");
            }

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
                    throw new InvalidOperationException($"Transaction date {request.IssueDate:yyyy-MM-dd} is locked against financial modifications.");
                }

                // 2. Resolve From-department name from LABOURMST if not provided
                var deptName = request.SourceDeptName;
                if (string.IsNullOrWhiteSpace(deptName))
                {
                    const string sqlDept = "SELECT LAB_NAME FROM LABOURMST WHERE LAB_CODE = @DeptCode";
                    deptName = await conn.ExecuteScalarAsync<string>(sqlDept, new { DeptCode = request.SourceDeptCode }, trans);
                }

                if (string.IsNullOrWhiteSpace(deptName))
                {
                    throw new InvalidOperationException($"Invalid department code {request.SourceDeptCode}. Department not found in LABOURMST.");
                }

                // 3. Resolve prefix strictly via IssuePrefixResolver (A2)
                var prefix = IssuePrefixResolver.Resolve(request.IssueMode, deptName);
                var (fyStart, fyEnd, fySuffix) = GetFinancialYearBounds(request.IssueDate);

                // 4. Sequence Generation under UPDLOCK/HOLDLOCK inside save transaction (A2)
                const string sqlSeq = @"
                    SELECT ISNULL(MAX(DBO.VAL(SUBSTRING(ISSUECODE, 6, 6))), 0)
                    FROM ISSUEMST WITH (UPDLOCK, HOLDLOCK)
                    WHERE LEFT(ISSUECODE, 4) = @Prefix 
                      AND ISSUEDATE >= @FyStart AND ISSUEDATE <= @FyEnd";

                var maxSeq = await conn.ExecuteScalarAsync<int>(sqlSeq, new { Prefix = prefix, FyStart = fyStart, FyEnd = fyEnd }, trans);
                var newSeq = maxSeq + 1;
                var issueCode = $"{prefix}/{newSeq:D6}/{fySuffix:D2}";

                // 5. Over-issue validation under transaction (Rule C.2-7)
                const string sqlCheckStock = @"
                    SELECT ISNULL(SUM(I_QTY), 0) AS STK 
                    FROM STOCKREGNEW WITH (UPDLOCK, HOLDLOCK)
                    WHERE SR_STK = 'Y'  
                      AND DT <= @Date 
                      AND I_CODE = @ItemCode
                      AND ISNULL(MRGNO, '') = @MrgNo
                      AND ISNULL(MAT_GRADE, '') = @Grade
                      AND ISNULL(MAT_SHADE, '') = @Shade
                      AND KH_CODE = @SourceDiv 
                      AND STORE_ID = @SourceStore 
                      AND STK_DIVID = @SourceDiv 
                      AND MAT_UNIT = @Uom";

                foreach (var line in request.Lines)
                {
                    var available = await conn.ExecuteScalarAsync<double?>(sqlCheckStock, new
                    {
                        Date = request.IssueDate.Date,
                        ItemCode = line.ItemCode,
                        MrgNo = line.MrgNo ?? string.Empty,
                        Grade = line.Grade ?? string.Empty,
                        Shade = line.Shade ?? string.Empty,
                        SourceDiv = request.SourceDivId,
                        SourceStore = request.SourceStoreId,
                        Uom = line.Uom
                    }, trans) ?? 0.0;

                    if (line.IssueQty > available)
                    {
                        throw new InvalidOperationException(
                            $"Issue Quantity ({line.IssueQty}) exceeds available stock ({available:F2}) for item '{line.ItemCode}' ({line.ItemName}).");
                    }
                }

                // Aggregate totals
                double totQty = request.Lines.Sum(l => l.IssueQty);
                int totItm = request.Lines.Count;
                double totPcs = request.Lines.Sum(l => l.IssPcs);
                var firstLine = request.Lines[0];

                // 6. DAYBOOK Row #1 (Item audit log before ISSUEMST insert, A8)
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

                // 7. Insert Header into ISSUEMST (A5)
                // Machine No. is written as '*' when blank/empty (A5)
                var machineNo = string.IsNullOrWhiteSpace(request.MachineNo) ? "*" : request.MachineNo.Trim();

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
                        @MachineNo, @Spindal, '', @LocationTag, GETDATE(), @Username, 'New',
                        @SlipNo, '', 0, '', 0, @Remark, 0,
                        0, 0, 0, 0, '00:00:00', 0,
                        '', 0, 0, 0, 0, @TotPcs,
                        @VehicleNo, @EwayBillNo
                    )";

                await conn.ExecuteAsync(sqlInsertHeader, new
                {
                    IssueCode = issueCode,
                    IssueDate = request.IssueDate.Date,
                    IssueMode = "To Department",
                    SourceDeptCode = request.SourceDeptCode,
                    SourceStoreId = request.SourceStoreId,
                    TotQty = totQty,
                    TotItm = totItm,
                    IssueSource = "Direct",
                    MachineNo = machineNo,
                    Spindal = request.Spindal ?? string.Empty,
                    LocationTag = locationTag,
                    Username = username,
                    SlipNo = request.SlipNo,
                    Remark = request.Remark ?? string.Empty,
                    TotPcs = totPcs,
                    VehicleNo = request.VehicleNo ?? string.Empty,
                    EwayBillNo = request.EwayBillNo ?? string.Empty
                }, trans);

                // 8. Insert Lines into ISSUEDET (A6) & Update ITEMMST (A7)
                // For this combination NO destination is captured (Dept_code, Rec_StoreID, Rec_CostID = 0)
                // binno is '' (A6), Req_Code is 'None' (A6)
                const string sqlInsertLine = @"
                    INSERT INTO issuedet (
                        IssueCode, Iss_SrNo, I_Code, Rec_Itcode, UOM, Iss_Cut, Rate, ReqQty, IssueQty, IssPcs, 
                        kh_code, Req_Code, MrgNo, Mat_Grade, Mat_Shade, Mat_Maker, ISD_ConNo, ISD_Remark, 
                        Dept_code, Iss_DepCode, Iss_StoreID, Iss_SubCode, Rec_StoreID, binno, CUST_ID, 
                        cops, cops_type, Rec_CostID
                    ) VALUES (
                        @IssueCode, @SrNo, @ItemCode, '', @UOM, 0, @Rate, 0, @IssueQty, @IssPcs, 
                        @SourceDivId, 'None', @MrgNo, @Grade, @Shade, @Maker, 0, @Remark, 
                        0, @SourceDeptCode, @SourceStoreId, 0, 0, '', 0, 
                        0, '', 0
                    )";

                const string sqlUpdateItem = @"
                    UPDATE ITEMMST 
                    SET I_RQTY = I_RQTY - @IssueQty, 
                        I_DEC = I_DEC - @DecValue 
                    WHERE I_CODE = @ItemCode";

                int sr = 1;
                foreach (var line in request.Lines)
                {
                    await conn.ExecuteAsync(sqlInsertLine, new
                    {
                        IssueCode = issueCode,
                        SrNo = sr++,
                        ItemCode = line.ItemCode,
                        UOM = line.Uom,
                        Rate = line.Rate,
                        IssueQty = line.IssueQty,
                        IssPcs = line.IssPcs,
                        SourceDivId = request.SourceDivId,
                        MrgNo = line.MrgNo ?? string.Empty,
                        Grade = line.Grade ?? string.Empty,
                        Shade = line.Shade ?? string.Empty,
                        Maker = line.Maker ?? string.Empty,
                        Remark = line.Remark ?? string.Empty,
                        SourceDeptCode = request.SourceDeptCode,
                        SourceStoreId = request.SourceStoreId
                    }, trans);

                    var decVal = Math.Round(line.IssueQty * line.Rate, 0);
                    await conn.ExecuteAsync(sqlUpdateItem, new
                    {
                        IssueQty = line.IssueQty,
                        DecValue = decVal,
                        ItemCode = line.ItemCode
                    }, trans);
                }

                // 9. Delete previous stock register records (position 6, A3)
                const string sqlDeleteStock = @"
                    DELETE FROM stockregnew 
                    WHERE sr_Code = @IssueCode AND mode IN ('Issue', 'Issue_Trf', 'IssueRet')";
                await conn.ExecuteAsync(sqlDeleteStock, new { IssueCode = issueCode }, trans);

                // 10. SINGLE-LEG ledger entry: Mode 'Issue' ONLY (A4). NO 'Issue_Trf' row!
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
                        IM.ISS_JOBCARD, ID.CUST_ID, id.uom, id.cops_type, id.kh_code 
                    FROM IssueMst AS IM 
                    LEFT JOIN IssueDet AS ID ON IM.IssueCode = ID.IssueCode 
                    LEFT JOIN labourmst AS lm ON lm.lab_code = id.iss_depcode 
                    LEFT JOIN storemst AS sm ON sm.Str_Code = id.iss_storeid 
                    LEFT JOIN partymst AS pm ON id.cust_id = pm.p_code 
                    WHERE IM.IssueCode = @IssueCode AND IM.ISSUEDATE >= @FyStart";

                await conn.ExecuteAsync(sqlStockOutgoing, new { IssueCode = issueCode, FyStart = fyStart }, trans);

                // 11. DAYBOOK Row #2 (Confirmation audit log after ledger, A8)
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

                return new IssueManagerSaveResultDto
                {
                    IssueCode = issueCode,
                    Success = true,
                    Message = $"Issue {issueCode} saved successfully."
                };
            }
            catch (Exception ex)
            {
                trans.Rollback();
                _logger.LogError(ex, "Failed to create Issue Manager transaction.");
                throw;
            }
        }

        public async Task<IssueManagerSaveResultDto> UpdateIssueAsync(
            string issueCode, IssueManagerCreateRequestDto request, string username, string locationTag, string companyName)
        {
            if (string.IsNullOrWhiteSpace(issueCode)) throw new ArgumentException("Issue code is required.", nameof(issueCode));
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.Lines == null || request.Lines.Count == 0)
                throw new InvalidOperationException("Issue Manager requires at least one line item.");

            if (!string.Equals(request.IssueMode?.Trim(), "To Department", StringComparison.OrdinalIgnoreCase) ||
                !string.Equals(request.IssueSource?.Trim(), "Direct", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException(
                    "Currently, only Issue Mode 'To Department' with Source 'Direct' is available. Other modes and sources are awaiting specification (SCOPE NOW).");
            }

            using var conn = CreateConnection();
            await conn.OpenAsync();
            using var trans = conn.BeginTransaction(IsolationLevel.Serializable);

            try
            {
                // 1. Fetch existing header to verify existence and check date locks
                const string sqlCheck = "SELECT IssueCode, IssueDate, TotQty, Issue_To FROM ISSUEMST WITH (UPDLOCK, HOLDLOCK) WHERE IssueCode = @IssueCode";
                var existing = await conn.QueryFirstOrDefaultAsync<dynamic>(sqlCheck, new { IssueCode = issueCode }, trans);
                if (existing == null)
                    throw new KeyNotFoundException($"Issue {issueCode} not found.");

                DateTime oldDate = existing.IssueDate;

                // Date Lock Verification (old date and new date)
                const string sqlLock = "SELECT COUNT(1) FROM LOCKDATAMST WHERE LDM_STDT = @Date";
                var isOldLocked = (await conn.ExecuteScalarAsync<int>(sqlLock, new { Date = oldDate.Date }, trans)) > 0;
                if (isOldLocked)
                    throw new InvalidOperationException($"Original transaction date {oldDate:yyyy-MM-dd} is locked against financial modifications.");

                var isNewLocked = (await conn.ExecuteScalarAsync<int>(sqlLock, new { Date = request.IssueDate.Date }, trans)) > 0;
                if (isNewLocked)
                    throw new InvalidOperationException($"New transaction date {request.IssueDate:yyyy-MM-dd} is locked against financial modifications.");

                // 2. Read existing lines from ISSUEDET to reverse previous stock adjustments
                const string sqlOldLines = "SELECT I_Code AS ItemCode, IssueQty, Rate FROM ISSUEDET WHERE IssueCode = @IssueCode";
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

                    await conn.ExecuteAsync(sqlRestoreItem, new
                    {
                        IssueQty = oldQty,
                        DecValue = oldDec,
                        ItemCode = oldItemCode
                    }, trans);
                }

                // 4. Purge existing stock ledger rows in STOCKREGNEW
                const string sqlDeleteStock = @"
                    DELETE FROM stockregnew 
                    WHERE sr_Code = @IssueCode AND mode IN ('Issue', 'Issue_Trf', 'IssueRet')";
                await conn.ExecuteAsync(sqlDeleteStock, new { IssueCode = issueCode }, trans);

                // 5. Delete existing line items in ISSUEDET
                const string sqlDeleteLines = "DELETE FROM issuedet WHERE IssueCode = @IssueCode";
                await conn.ExecuteAsync(sqlDeleteLines, new { IssueCode = issueCode }, trans);

                // 6. Over-issue validation under transaction with restored stock
                const string sqlCheckStock = @"
                    SELECT ISNULL(SUM(I_QTY), 0) AS STK 
                    FROM STOCKREGNEW WITH (UPDLOCK, HOLDLOCK)
                    WHERE SR_STK = 'Y'  
                      AND DT <= @Date 
                      AND I_CODE = @ItemCode
                      AND ISNULL(MRGNO, '') = @MrgNo
                      AND ISNULL(MAT_GRADE, '') = @Grade
                      AND ISNULL(MAT_SHADE, '') = @Shade
                      AND KH_CODE = @SourceDiv 
                      AND STORE_ID = @SourceStore 
                      AND STK_DIVID = @SourceDiv 
                      AND MAT_UNIT = @Uom";

                foreach (var line in request.Lines)
                {
                    var available = await conn.ExecuteScalarAsync<double?>(sqlCheckStock, new
                    {
                        Date = request.IssueDate.Date,
                        ItemCode = line.ItemCode,
                        MrgNo = line.MrgNo ?? string.Empty,
                        Grade = line.Grade ?? string.Empty,
                        Shade = line.Shade ?? string.Empty,
                        SourceDiv = request.SourceDivId,
                        SourceStore = request.SourceStoreId,
                        Uom = line.Uom
                    }, trans) ?? 0.0;

                    if (line.IssueQty > available)
                    {
                        throw new InvalidOperationException(
                            $"Issue Quantity ({line.IssueQty}) exceeds available stock ({available:F2}) for item '{line.ItemCode}' ({line.ItemName}).");
                    }
                }

                // Resolve department name
                var deptName = request.SourceDeptName;
                if (string.IsNullOrWhiteSpace(deptName))
                {
                    const string sqlDept = "SELECT LAB_NAME FROM LABOURMST WHERE LAB_CODE = @DeptCode";
                    deptName = await conn.ExecuteScalarAsync<string>(sqlDept, new { DeptCode = request.SourceDeptCode }, trans);
                }
                if (string.IsNullOrWhiteSpace(deptName))
                {
                    throw new InvalidOperationException($"Invalid department code {request.SourceDeptCode}. Department not found in LABOURMST.");
                }

                // Aggregate totals
                double totQty = request.Lines.Sum(l => l.IssueQty);
                int totItm = request.Lines.Count;
                double totPcs = request.Lines.Sum(l => l.IssPcs);
                var machineNo = string.IsNullOrWhiteSpace(request.MachineNo) ? "*" : request.MachineNo.Trim();

                // 7. Update master header in ISSUEMST
                const string sqlUpdateHeader = @"
                    UPDATE IssueMst SET 
                        IssueDate = @IssueDate,
                        Issue_To = @SourceDeptCode,
                        Str_Code = @SourceStoreId,
                        TotQty = @TotQty,
                        TotItm = @TotItm,
                        TotPcs = @TotPcs,
                        Iss_MacNo = @MachineNo,
                        Iss_Spin = @Spindal,
                        Iss_SlipNo = @SlipNo,
                        remark = @Remark,
                        Iss_VhNo = @VehicleNo,
                        Iss_Eway_Bill_No = @EwayBillNo,
                        Iss_UsrName = @Username,
                        Iss_EDate = GETDATE(),
                        Iss_EMode = 'Update'
                    WHERE IssueCode = @IssueCode";

                await conn.ExecuteAsync(sqlUpdateHeader, new
                {
                    IssueCode = issueCode,
                    IssueDate = request.IssueDate.Date,
                    SourceDeptCode = request.SourceDeptCode,
                    SourceStoreId = request.SourceStoreId,
                    TotQty = totQty,
                    TotItm = totItm,
                    TotPcs = totPcs,
                    MachineNo = machineNo,
                    Spindal = request.Spindal ?? string.Empty,
                    SlipNo = request.SlipNo,
                    Remark = request.Remark ?? string.Empty,
                    VehicleNo = request.VehicleNo ?? string.Empty,
                    EwayBillNo = request.EwayBillNo ?? string.Empty,
                    Username = username
                }, trans);

                // 8. Insert updated detail rows into ISSUEDET & update ITEMMST
                const string sqlInsertLine = @"
                    INSERT INTO issuedet (
                        IssueCode, Iss_SrNo, I_Code, Rec_Itcode, UOM, Iss_Cut, Rate, ReqQty, IssueQty, IssPcs, 
                        kh_code, Req_Code, MrgNo, Mat_Grade, Mat_Shade, Mat_Maker, ISD_ConNo, ISD_Remark, 
                        Dept_code, Iss_DepCode, Iss_StoreID, Iss_SubCode, Rec_StoreID, binno, CUST_ID, 
                        cops, cops_type, Rec_CostID
                    ) VALUES (
                        @IssueCode, @SrNo, @ItemCode, '', @UOM, 0, @Rate, 0, @IssueQty, @IssPcs, 
                        @SourceDivId, 'None', @MrgNo, @Grade, @Shade, @Maker, 0, @Remark, 
                        0, @SourceDeptCode, @SourceStoreId, 0, 0, '', 0, 
                        0, '', 0
                    )";

                const string sqlDeductItem = @"
                    UPDATE ITEMMST 
                    SET I_RQTY = I_RQTY - @IssueQty, 
                        I_DEC = I_DEC - @DecValue 
                    WHERE I_CODE = @ItemCode";

                int sr = 1;
                foreach (var line in request.Lines)
                {
                    await conn.ExecuteAsync(sqlInsertLine, new
                    {
                        IssueCode = issueCode,
                        SrNo = sr++,
                        ItemCode = line.ItemCode,
                        UOM = line.Uom,
                        Rate = line.Rate,
                        IssueQty = line.IssueQty,
                        IssPcs = line.IssPcs,
                        SourceDivId = request.SourceDivId,
                        MrgNo = line.MrgNo ?? string.Empty,
                        Grade = line.Grade ?? string.Empty,
                        Shade = line.Shade ?? string.Empty,
                        Maker = line.Maker ?? string.Empty,
                        Remark = line.Remark ?? string.Empty,
                        SourceDeptCode = request.SourceDeptCode,
                        SourceStoreId = request.SourceStoreId
                    }, trans);

                    var decVal = Math.Round(line.IssueQty * line.Rate, 0);
                    await conn.ExecuteAsync(sqlDeductItem, new
                    {
                        IssueQty = line.IssueQty,
                        DecValue = decVal,
                        ItemCode = line.ItemCode
                    }, trans);
                }

                // 9. SINGLE-LEG ledger entry: Mode 'Issue' ONLY (A4). NO 'Issue_Trf' row!
                var (fyStart, _, _) = GetFinancialYearBounds(request.IssueDate);

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
                        IM.ISS_JOBCARD, ID.CUST_ID, id.uom, id.cops_type, id.kh_code 
                    FROM IssueMst AS IM 
                    LEFT JOIN IssueDet AS ID ON IM.IssueCode = ID.IssueCode 
                    LEFT JOIN labourmst AS lm ON lm.lab_code = id.iss_depcode 
                    LEFT JOIN storemst AS sm ON sm.Str_Code = id.iss_storeid 
                    LEFT JOIN partymst AS pm ON id.cust_id = pm.p_code 
                    WHERE IM.IssueCode = @IssueCode AND IM.ISSUEDATE >= @FyStart";

                await conn.ExecuteAsync(sqlStockOutgoing, new { IssueCode = issueCode, FyStart = fyStart }, trans);

                // 10. DAYBOOK Audit entry for UPDATE
                const string sqlDaybook = @"
                    INSERT INTO DAYBOOK (DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES (GETDATE(), @Username, @DeptName, @TotQty, @DocNo, 'UPDATE', 'ISU', 1, @CompanyName)";

                await conn.ExecuteAsync(sqlDaybook, new
                {
                    Username = username,
                    DeptName = deptName,
                    TotQty = totQty,
                    DocNo = issueCode,
                    CompanyName = companyName
                }, trans);

                trans.Commit();

                return new IssueManagerSaveResultDto
                {
                    IssueCode = issueCode,
                    Success = true,
                    Message = $"Issue {issueCode} updated successfully."
                };
            }
            catch (Exception ex)
            {
                trans.Rollback();
                _logger.LogError(ex, "Failed to update Issue Manager transaction {IssueCode}.", issueCode);
                throw;
            }
        }

        public async Task<IssueManagerSaveResultDto> DeleteIssueAsync(string issueCode, string username, string companyName)
        {
            if (string.IsNullOrWhiteSpace(issueCode)) throw new ArgumentException("Issue code is required.", nameof(issueCode));

            using var conn = CreateConnection();
            await conn.OpenAsync();
            using var trans = conn.BeginTransaction(IsolationLevel.Serializable);

            try
            {
                // 1. Fetch existing header to verify existence and check date locks
                const string sqlCheck = "SELECT IssueCode, IssueDate, TotQty, Issue_To FROM ISSUEMST WITH (UPDLOCK, HOLDLOCK) WHERE IssueCode = @IssueCode";
                var existing = await conn.QueryFirstOrDefaultAsync<dynamic>(sqlCheck, new { IssueCode = issueCode }, trans);
                if (existing == null)
                    throw new KeyNotFoundException($"Issue {issueCode} not found.");

                DateTime issueDate = existing.IssueDate;
                double totQty = (double)(existing.TotQty ?? 0.0);
                int deptCode = (int)(existing.Issue_To ?? 0);

                // 2. Date Lock Verification
                const string sqlLock = "SELECT COUNT(1) FROM LOCKDATAMST WHERE LDM_STDT = @Date";
                var isLocked = (await conn.ExecuteScalarAsync<int>(sqlLock, new { Date = issueDate.Date }, trans)) > 0;
                if (isLocked)
                    throw new InvalidOperationException($"Transaction date {issueDate:yyyy-MM-dd} is locked against financial deletion.");

                // 3. Read lines from ISSUEDET to reverse stock balances in ITEMMST
                const string sqlLines = "SELECT I_Code AS ItemCode, IssueQty, Rate FROM ISSUEDET WHERE IssueCode = @IssueCode";
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

                    await conn.ExecuteAsync(sqlRestoreItem, new
                    {
                        IssueQty = qty,
                        DecValue = decVal,
                        ItemCode = itemCode
                    }, trans);
                }

                // 4. Purge STOCKREGNEW
                const string sqlDeleteStock = @"
                    DELETE FROM stockregnew 
                    WHERE sr_Code = @IssueCode AND mode IN ('Issue', 'Issue_Trf', 'IssueRet')";
                await conn.ExecuteAsync(sqlDeleteStock, new { IssueCode = issueCode }, trans);

                // 5. Delete ISSUEDET lines
                const string sqlDeleteLines = "DELETE FROM issuedet WHERE IssueCode = @IssueCode";
                await conn.ExecuteAsync(sqlDeleteLines, new { IssueCode = issueCode }, trans);

                // 6. Delete ISSUEMST header
                const string sqlDeleteHeader = "DELETE FROM IssueMst WHERE IssueCode = @IssueCode";
                await conn.ExecuteAsync(sqlDeleteHeader, new { IssueCode = issueCode }, trans);

                // Resolve department name for DAYBOOK audit
                const string sqlDept = "SELECT LAB_NAME FROM LABOURMST WHERE LAB_CODE = @DeptCode";
                var deptName = await conn.ExecuteScalarAsync<string>(sqlDept, new { DeptCode = deptCode }, trans) ?? "ISSUE";

                // 7. DAYBOOK row for DELETE
                const string sqlDaybook = @"
                    INSERT INTO DAYBOOK (DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES (GETDATE(), @Username, @DeptName, @TotQty, @DocNo, 'DELETE', 'ISU', 1, @CompanyName)";

                await conn.ExecuteAsync(sqlDaybook, new
                {
                    Username = username,
                    DeptName = deptName,
                    TotQty = totQty,
                    DocNo = issueCode,
                    CompanyName = companyName
                }, trans);

                trans.Commit();

                return new IssueManagerSaveResultDto
                {
                    IssueCode = issueCode,
                    Success = true,
                    Message = $"Issue {issueCode} deleted and inventory restored successfully."
                };
            }
            catch (Exception ex)
            {
                trans.Rollback();
                _logger.LogError(ex, "Failed to delete Issue {IssueCode}.", issueCode);
                throw;
            }
        }
    }
}
