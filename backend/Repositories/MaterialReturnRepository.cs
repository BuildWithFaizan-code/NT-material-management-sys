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
    public class MaterialReturnRepository : IMaterialReturnRepository
    {
        private readonly string _connectionString;
        private readonly ILogger<MaterialReturnRepository> _logger;

        public MaterialReturnRepository(IConfiguration configuration, ILogger<MaterialReturnRepository> logger)
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

        private static string ResolvePrefix(string? retMode, string? entityName)
        {
            var mode = retMode?.Trim();
            var name = entityName?.Trim();

            if (string.Equals(mode, "From Department", StringComparison.OrdinalIgnoreCase) &&
                string.Equals(name, "REGULAR", StringComparison.OrdinalIgnoreCase))
            {
                return "REGU";
            }

            if (!string.IsNullOrWhiteSpace(name) && name.Length >= 4)
            {
                return name.Substring(0, 4).ToUpperInvariant();
            }

            return "ISSR";
        }

        public async Task<MaterialReturnLookupsDto> GetLookupsAsync()
        {
            var lookups = new MaterialReturnLookupsDto();
            using var conn = CreateConnection();

            // 1. Departments (LABOURMST)
            const string sqlDepts = @"
                SELECT LAB_CODE AS Id, CAST(LAB_CODE AS NVARCHAR(50)) AS Code, LAB_NAME AS Name 
                FROM LABOURMST 
                WHERE (LAB_STATUS = '' OR LAB_STATUS IS NULL OR LAB_STATUS = 'YES') 
                ORDER BY LAB_NAME";
            lookups.Departments = (await conn.QueryAsync<MaterialReturnLookupItemDto>(sqlDepts)).ToList();

            // 2. Stores / Plant (STOREMST)
            const string sqlStores = @"
                SELECT STR_CODE AS Id, CAST(STR_CODE AS NVARCHAR(50)) AS Code, STR_NAME AS Name 
                FROM STOREMST 
                WHERE STR_NAME <> '' 
                ORDER BY STR_NAME";
            lookups.Stores = (await conn.QueryAsync<MaterialReturnLookupItemDto>(sqlStores)).ToList();

            // 3. Divisions / Cost Centers (KHATAMST)
            const string sqlDivs = @"
                SELECT KH_CODE AS Id, CAST(KH_CODE AS NVARCHAR(50)) AS Code, KH_NAME AS Name 
                FROM KHATAMST 
                CROSS APPLY DBO.FNSPLITSTRING(KH_BRANCH, ',') 
                WHERE KH_NAME <> '' 
                  AND (KH_DISPLAY IS NULL OR KH_DISPLAY = 0) 
                  AND SPLITDATA = '1' 
                ORDER BY KH_NAME";
            lookups.Divisions = (await conn.QueryAsync<MaterialReturnLookupItemDto>(sqlDivs)).ToList();

            // 4. Operators (OPERATORMST)
            const string sqlOpers = @"
                SELECT OPER_CODE AS OperCode, OPER_NAME AS OperName 
                FROM OPERATORMST 
                ORDER BY OPER_NAME";
            lookups.Operators = (await conn.QueryAsync<MaterialReturnOperatorDto>(sqlOpers)).ToList();

            // 5. Parties / Suppliers & Customers (PARTYMST)
            const string sqlParties = @"
                SELECT P_CODE AS Id, CAST(P_CODE AS NVARCHAR(50)) AS Code, P_NAME AS Name 
                FROM PARTYMST 
                ORDER BY P_NAME";
            lookups.Parties = (await conn.QueryAsync<MaterialReturnLookupItemDto>(sqlParties)).ToList();

            // 6. Return Modes
            lookups.ReturnModes = new List<string>
            {
                "From Department",
                "To Supplier",
                "To Customer"
            };

            // 7. Return Sources
            lookups.ReturnSources = new List<string>
            {
                "Direct",
                "Issued",
                "Production",
                "Line Based",
                "Job_GRN",
                "WIP",
                "PROD_ORDER",
                "Service Order Based"
            };

            // 8. Default Address (BUSYMST By_Code = 1)
            const string sqlAddr = @"
                SELECT TOP 1 ISNULL(By_Add1, '') + ' ' + ISNULL(By_Add2, '') 
                FROM BUSYMST 
                WHERE By_Code = 1";
            lookups.DefaultAddress = (await conn.ExecuteScalarAsync<string>(sqlAddr)) ?? string.Empty;

            return lookups;
        }

        public async Task<string> GetNextPreviewCodeAsync(DateTime date, string retMode, string entityName)
        {
            var prefix = ResolvePrefix(retMode, entityName);
            var (fyStart, fyEnd, fySuffix) = GetFinancialYearBounds(date);

            using var conn = CreateConnection();
            const string sql = @"
                SELECT ISNULL(MAX(DBO.VAL(SUBSTRING(RETCODE, 6, 6))), 0)
                FROM ISSUERETMST WITH (NOLOCK)
                WHERE LEFT(RETCODE, 4) = @Prefix 
                  AND RETDATE >= @FyStart AND RETDATE <= @FyEnd";

            var maxSeq = await conn.ExecuteScalarAsync<int>(sql, new { Prefix = prefix, FyStart = fyStart, FyEnd = fyEnd });
            var nextSeq = maxSeq + 1;

            return $"{prefix}/{nextSeq:D6}/{fySuffix:D2}";
        }

        public async Task<MaterialReturnStockCatalogPagedResultDto> GetStockCatalogAsync(
            DateTime date, int deptCode, int storeId, int divId, string? searchQuery, int page, int pageSize)
        {
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 50;
            if (pageSize > 200) pageSize = 200;
            var offset = (page - 1) * pageSize;

            using var conn = CreateConnection();

            const string sqlCount = @"
                SELECT COUNT(1) 
                FROM ITEMMST AS IM WITH (NOLOCK)
                WHERE (IM.I_BLOCK IS NULL OR IM.I_BLOCK = 0) AND IM.I_CODE <> ''
                  AND (@Search IS NULL OR @Search = '' OR IM.I_CODE LIKE '%' + @Search + '%' OR IM.I_NAME1 LIKE '%' + @Search + '%')";

            var totalCount = await conn.ExecuteScalarAsync<int>(sqlCount, new { Search = searchQuery?.Trim() });

            const string sqlItems = @"
                SELECT 
                    IM.I_CODE AS ItemCode, 
                    IM.I_NAME1 AS ItemName, 
                    ISNULL(UM.UNIT_NAME, '') AS Uom, 
                    ISNULL(IM.I_RQTY, 0) AS BalanceQty, 
                    ISNULL(STK.CurrentStock, ISNULL(IM.I_RQTY, 0)) AS Stock, 
                    ISNULL(IM.I_PRATE, 0) AS AvgRate, 
                    ISNULL(IM.I_HSN, '') AS HsnCode, 
                    0 AS Cops, 
                    ISNULL(H.SIM_SECUNIT, '') AS ConvUom, 
                    ISNULL(H.SIM_CONVQTY, 0) AS ConvQty, 
                    ISNULL(E.IMR_MRGNO, '') AS MrgNo, 
                    ISNULL(SK.SKU_GRADE, '') AS MatGrade, 
                    ISNULL(SK.SKU_SHADENM, '') AS MatShade, 
                    ISNULL(E.IMR_MAKER, '') AS MatMaker, 
                    ISNULL(H.SIM_BIN, '') AS BinNo, 
                    ISNULL(D.TAX_CGPER, 0) AS Cgper, 
                    ISNULL(D.TAX_SGPER, 0) AS Sgper, 
                    ISNULL(D.TAX_IGPER, 0) AS Igper 
                FROM ITEMMST AS IM WITH (NOLOCK) 
                LEFT JOIN UNITMST AS UM WITH (NOLOCK) ON IM.I_UOM = UM.UNIT_CODE 
                LEFT JOIN TAX_SLAB_MST AS D WITH (NOLOCK) ON IM.I_TAXSLAB = D.TAX_CODE 
                LEFT JOIN SUBITEMMST AS H WITH (NOLOCK) ON IM.I_CODE = H.SIM_CODE 
                OUTER APPLY (
                    SELECT TOP 1 IMR_MRGNO, IMR_MAKER 
                    FROM ITEMMARGE WITH (NOLOCK) 
                    WHERE I_CODE = IM.I_CODE
                ) AS E 
                OUTER APPLY (
                    SELECT TOP 1 SKU_GRADE, SKU_SHADENM 
                    FROM SKUMST WITH (NOLOCK) 
                    WHERE SKU_CODE = IM.I_CODE
                ) AS SK 
                OUTER APPLY (
                    SELECT ISNULL(SUM(I_QTY), 0) AS CurrentStock 
                    FROM STOCKREGNEW WITH (NOLOCK) 
                    WHERE SR_STK = 'Y' 
                      AND DT <= @Date 
                      AND I_CODE = IM.I_CODE 
                      AND (@StoreId = 0 OR STORE_ID = @StoreId)
                ) AS STK 
                WHERE (IM.I_BLOCK IS NULL OR IM.I_BLOCK = 0) AND IM.I_CODE <> '' 
                  AND (@Search IS NULL OR @Search = '' OR IM.I_CODE LIKE '%' + @Search + '%' OR IM.I_NAME1 LIKE '%' + @Search + '%') 
                ORDER BY IM.I_NAME1 
                OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY";

            var items = (await conn.QueryAsync<MaterialReturnCatalogItemDto>(sqlItems, new
            {
                Date = date.Date,
                StoreId = storeId,
                Search = searchQuery?.Trim(),
                Offset = offset,
                PageSize = pageSize
            })).ToList();

            return new MaterialReturnStockCatalogPagedResultDto
            {
                Items = items,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            };
        }

        public async Task<double> CheckStockAvailabilityAsync(
            DateTime date, string currentDocNo, string itemCode, string mrgNo, string grade, string shade,
            int deptCode, int storeId, int divId, int uom)
        {
            using var conn = CreateConnection();
            const string sql = @"
                SELECT ISNULL(SUM(I_QTY), 0) AS STK 
                FROM STOCKREGNEW WITH (NOLOCK)
                WHERE SR_STK = 'Y' 
                  AND DT <= @Date 
                  AND I_CODE = @ItemCode 
                  AND ISNULL(MRGNO, '') = @MrgNo 
                  AND ISNULL(MAT_GRADE, '') = @Grade 
                  AND ISNULL(MAT_SHADE, '') = @Shade 
                  AND STORE_ID = @StoreId 
                  AND STK_DIVID = @DivId 
                  AND MAT_UNIT = @Uom";

            var stock = await conn.ExecuteScalarAsync<double?>(sql, new
            {
                Date = date.Date,
                ItemCode = itemCode,
                MrgNo = mrgNo ?? string.Empty,
                Grade = grade ?? string.Empty,
                Shade = shade ?? string.Empty,
                StoreId = storeId,
                DivId = divId,
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
                SELECT DISTINCT TOP 10 REMARK 
                FROM ISSUERETMST 
                WHERE REMARK IS NOT NULL AND REMARK <> '' 
                  AND (@Query IS NULL OR @Query = '' OR REMARK LIKE '%' + @Query + '%') 
                ORDER BY REMARK";

            var results = await conn.QueryAsync<string>(sql, new { Query = query?.Trim() });
            return results.ToList();
        }

        public async Task<MaterialReturnPagedListDto> GetReturnsAsync(
            DateTime? fromDate, DateTime? toDate, string? searchQuery, string? retMode, int page, int pageSize)
        {
            if (page < 1) page = 1;
            if (pageSize < 1) pageSize = 25;
            var offset = (page - 1) * pageSize;

            using var conn = CreateConnection();

            var whereClauses = new List<string>();
            var param = new DynamicParameters();

            if (fromDate.HasValue)
            {
                whereClauses.Add("IRM.RetDate >= @FromDate");
                param.Add("FromDate", fromDate.Value.Date);
            }

            if (toDate.HasValue)
            {
                whereClauses.Add("IRM.RetDate <= @ToDate");
                param.Add("ToDate", toDate.Value.Date);
            }

            if (!string.IsNullOrWhiteSpace(retMode) && !retMode.Equals("All", StringComparison.OrdinalIgnoreCase))
            {
                whereClauses.Add("IRM.RetMode = @RetMode");
                param.Add("RetMode", retMode.Trim());
            }

            if (!string.IsNullOrWhiteSpace(searchQuery))
            {
                whereClauses.Add("(IRM.RetCode LIKE '%' + @Search + '%' OR IRM.Remark LIKE '%' + @Search + '%' OR LM.LAB_NAME LIKE '%' + @Search + '%' OR PM.P_NAME LIKE '%' + @Search + '%')");
                param.Add("Search", searchQuery.Trim());
            }

            var whereSql = whereClauses.Count > 0 ? "WHERE " + string.Join(" AND ", whereClauses) : string.Empty;

            var sqlCount = $@"
                SELECT COUNT(1) 
                FROM IssueRetMst AS IRM 
                LEFT JOIN LABOURMST AS LM ON LM.LAB_CODE = IRM.Ret_To 
                LEFT JOIN PARTYMST AS PM ON PM.P_CODE = IRM.Ret_To 
                {whereSql}";

            var totalCount = await conn.ExecuteScalarAsync<int>(sqlCount, param);

            param.Add("Offset", offset);
            param.Add("PageSize", pageSize);

            var sqlRecords = $@"
                SELECT 
                    IRM.RetCode AS RetCode, 
                    IRM.RetDate AS RetDate, 
                    IRM.RetMode AS RetMode, 
                    ISNULL(IRM.RetType, 'Direct') AS RetType, 
                    IRM.Ret_To AS RetTo, 
                    CASE 
                        WHEN IRM.RetMode = 'From Department' THEN ISNULL(LM.LAB_NAME, '') 
                        ELSE ISNULL(PM.P_NAME, '') 
                    END AS RetToName, 
                    ISNULL(IRM.Str_Code, 1) AS StoreCode, 
                    ISNULL(SM.STR_NAME, '') AS StoreName, 
                    ISNULL(IRM.TotQty, 0) AS TotQty, 
                    ISNULL(IRM.TotItm, 0) AS TotItm, 
                    ISNULL(IRM.Remark, '') AS Remark, 
                    ISNULL(IRM.isGP, 0) AS IsGp, 
                    ISNULL(IRM.Rec_OperCode, 0) AS OperCode, 
                    ISNULL(OP.OPER_NAME, '') AS OperName, 
                    ISNULL(IRM.IRM_UsrName, '') AS CreatedBy, 
                    IRM.IRM_EDate AS CreatedDate,
                    (SELECT ISNULL(SUM(Amt), 0) FROM IssueRetDet WHERE RetCode = IRM.RetCode) AS TotAmt,
                    (SELECT ISNULL(SUM(Net_Amt), 0) FROM IssueRetDet WHERE RetCode = IRM.RetCode) AS NetTotAmt
                FROM IssueRetMst AS IRM 
                LEFT JOIN LABOURMST AS LM ON LM.LAB_CODE = IRM.Ret_To 
                LEFT JOIN PARTYMST AS PM ON PM.P_CODE = IRM.Ret_To 
                LEFT JOIN STOREMST AS SM ON SM.STR_CODE = IRM.Str_Code 
                LEFT JOIN OPERATORMST AS OP ON OP.OPER_CODE = IRM.Rec_OperCode 
                {whereSql} 
                ORDER BY IRM.RetDate DESC, IRM.RetCode DESC 
                OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY";

            var records = (await conn.QueryAsync<MaterialReturnGridRecordDto>(sqlRecords, param)).ToList();

            return new MaterialReturnPagedListDto
            {
                Records = records,
                TotalCount = totalCount
            };
        }

        public async Task<MaterialReturnDetailDto?> GetReturnByCodeAsync(string retCode)
        {
            if (string.IsNullOrWhiteSpace(retCode)) return null;

            using var conn = CreateConnection();

            const string sqlHeader = @"
                SELECT 
                    IRM.RetCode AS RetCode, 
                    IRM.RetDate AS RetDate, 
                    IRM.RetMode AS RetMode, 
                    ISNULL(IRM.RetType, 'Direct') AS RetType, 
                    IRM.Ret_To AS RetTo, 
                    CASE 
                        WHEN IRM.RetMode = 'From Department' THEN ISNULL(LM.LAB_NAME, '') 
                        ELSE ISNULL(PM.P_NAME, '') 
                    END AS RetToName, 
                    ISNULL(IRM.Str_Code, 1) AS StoreCode, 
                    ISNULL(SM.STR_NAME, '') AS StoreName, 
                    ISNULL(IRM.TotQty, 0) AS TotQty, 
                    ISNULL(IRM.TotItm, 0) AS TotItm, 
                    ISNULL(IRM.Remark, '') AS Remark, 
                    ISNULL(IRM.isGP, 0) AS IsGp, 
                    ISNULL(IRM.Rec_OperCode, 0) AS OperCode, 
                    ISNULL(OP.OPER_NAME, '') AS OperName, 
                    ISNULL(IRM.IRM_UsrName, '') AS CreatedBy, 
                    IRM.IRM_EDate AS CreatedDate,
                    (SELECT ISNULL(SUM(Amt), 0) FROM IssueRetDet WHERE RetCode = IRM.RetCode) AS TotAmt,
                    (SELECT ISNULL(SUM(Net_Amt), 0) FROM IssueRetDet WHERE RetCode = IRM.RetCode) AS NetTotAmt
                FROM IssueRetMst AS IRM 
                LEFT JOIN LABOURMST AS LM ON LM.LAB_CODE = IRM.Ret_To 
                LEFT JOIN PARTYMST AS PM ON PM.P_CODE = IRM.Ret_To 
                LEFT JOIN STOREMST AS SM ON SM.STR_CODE = IRM.Str_Code 
                LEFT JOIN OPERATORMST AS OP ON OP.OPER_CODE = IRM.Rec_OperCode 
                WHERE IRM.RetCode = @RetCode";

            var header = await conn.QueryFirstOrDefaultAsync<MaterialReturnGridRecordDto>(sqlHeader, new { RetCode = retCode });
            if (header == null) return null;

            const string sqlLines = @"
                SELECT 
                    IRD.Retid AS SrNo, 
                    IRD.I_Code AS ItemCode, 
                    ISNULL(IM.I_NAME1, '') AS ItemName, 
                    ISNULL(IRD.IRD_HSN, ISNULL(IM.I_HSN, '')) AS Hsn, 
                    ISNULL(IRD.IRD_mrgNo, '') AS MrgNo, 
                    ISNULL(IRD.MAT_GRADE, '') AS Grade, 
                    ISNULL(IRD.MAT_SHADE, '') AS Shade, 
                    ISNULL(IRD.MAT_MAKER, '') AS Maker, 
                    ISNULL(IRD.UOM, 0) AS Uom, 
                    ISNULL(UM.UNIT_NAME, '') AS UnitName, 
                    ISNULL(IRD.RetQty, 0) AS Qty, 
                    ISNULL(IRD.Rate, 0) AS Rate, 
                    ISNULL(IRD.Amt, 0) AS Amt, 
                    ISNULL(IRD.RETCOPS, 0) AS Cops, 
                    0 AS Stock, 
                    ISNULL(IRD.CGPER, 0) AS CGPer, 
                    ISNULL(IRD.CGAMT, 0) AS CGAmt, 
                    ISNULL(IRD.SGPER, 0) AS SGPer, 
                    ISNULL(IRD.SGAMT, 0) AS SGAmt, 
                    ISNULL(IRD.IGPER, 0) AS IGPer, 
                    ISNULL(IRD.IGAMT, 0) AS IGAmt, 
                    ISNULL(IRD.NET_AMT, 0) AS NetAmt, 
                    ISNULL(IRD.RET_REMARK, '') AS Remark 
                FROM IssueRetDet AS IRD 
                LEFT JOIN ITEMMST AS IM ON IM.I_CODE = IRD.I_Code 
                LEFT JOIN UNITMST AS UM ON UM.UNIT_CODE = IRD.UOM 
                WHERE IRD.RetCode = @RetCode 
                ORDER BY IRD.Retid";

            var lines = (await conn.QueryAsync<MaterialReturnLineInputDto>(sqlLines, new { RetCode = retCode })).ToList();

            return new MaterialReturnDetailDto
            {
                Header = header,
                Lines = lines
            };
        }

        public async Task<MaterialReturnSaveResultDto> CreateReturnAsync(
            MaterialReturnCreateRequestDto request, string username, string locationTag, string companyName)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.Lines == null || request.Lines.Count == 0)
                throw new InvalidOperationException("Material return requires at least one line item.");

            using var conn = CreateConnection();
            await conn.OpenAsync();
            using var trans = conn.BeginTransaction(IsolationLevel.Serializable);

            try
            {
                // 1. Date Lock Enforcement
                const string sqlLock = "SELECT COUNT(1) FROM LOCKDATAMST WHERE LDM_STDT = @Date";
                var isLocked = (await conn.ExecuteScalarAsync<int>(sqlLock, new { Date = request.RetDate.Date }, trans)) > 0;
                if (isLocked)
                {
                    throw new InvalidOperationException($"Transaction date {request.RetDate:yyyy-MM-dd} is locked against financial modifications.");
                }

                // 2. Resolve Entity Name
                int parsedRetTo = int.TryParse(request.RetTo, out var rCode) ? rCode : 1;
                var entityName = request.RetToName;
                if (string.IsNullOrWhiteSpace(entityName))
                {
                    if (string.Equals(request.RetMode, "From Department", StringComparison.OrdinalIgnoreCase))
                    {
                        const string sqlDept = "SELECT LAB_NAME FROM LABOURMST WHERE LAB_CODE = @Code";
                        entityName = await conn.ExecuteScalarAsync<string>(sqlDept, new { Code = parsedRetTo }, trans);
                    }
                    else
                    {
                        const string sqlParty = "SELECT P_NAME FROM PARTYMST WHERE P_CODE = @Code";
                        entityName = await conn.ExecuteScalarAsync<string>(sqlParty, new { Code = parsedRetTo }, trans);
                    }
                }

                // 3. Resolve prefix and sequence under UPDLOCK/HOLDLOCK
                var prefix = ResolvePrefix(request.RetMode, entityName);
                var (fyStart, fyEnd, fySuffix) = GetFinancialYearBounds(request.RetDate);

                const string sqlSeq = @"
                    SELECT ISNULL(MAX(DBO.VAL(SUBSTRING(RETCODE, 6, 6))), 0)
                    FROM ISSUERETMST WITH (UPDLOCK, HOLDLOCK)
                    WHERE LEFT(RETCODE, 4) = @Prefix 
                      AND RETDATE >= @FyStart AND RETDATE <= @FyEnd";

                var maxSeq = await conn.ExecuteScalarAsync<int>(sqlSeq, new { Prefix = prefix, FyStart = fyStart, FyEnd = fyEnd }, trans);
                var newSeq = maxSeq + 1;
                var retCode = $"{prefix}/{newSeq:D6}/{fySuffix:D2}";

                // 4. Totals Calculation
                double totQty = request.Lines.Sum(l => l.Qty);
                int totItm = request.Lines.Count;
                var firstLine = request.Lines[0];

                // 5. DAYBOOK Row #1 (Item audit log before header insert)
                const string sqlDaybook1 = @"
                    INSERT INTO DAYBOOK (DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES (GETDATE(), @Username, @FirstItemName, @FirstItemQty, @DocNo, 'NEW', 'RTN', 1, @CompanyName)";

                await conn.ExecuteAsync(sqlDaybook1, new
                {
                    Username = username,
                    FirstItemName = string.IsNullOrWhiteSpace(firstLine.ItemName) ? firstLine.ItemCode : firstLine.ItemName,
                    FirstItemQty = firstLine.Qty,
                    DocNo = retCode,
                    CompanyName = companyName
                }, trans);

                int parsedOper = int.TryParse(request.OperatorCode, out var opCode) ? opCode : (request.OperCode > 0 ? request.OperCode : 1);
                string retType = !string.IsNullOrWhiteSpace(request.Source) ? request.Source.Trim() : (!string.IsNullOrWhiteSpace(request.RetType) ? request.RetType.Trim() : "Direct");

                // 6. Insert Header into IssueRetMst
                const string sqlInsertHeader = @"
                    INSERT INTO IssueRetMst (
                        RetCode, RetDate, RetMode, Ret_To, Str_Code, TotQty, TotItm, remark, RetType, 
                        IRM_LOC, IRM_EDate, IRM_UsrName, IRM_EMode, TypeID, isGP, IRM_AddCD, Rec_OperCode, IRM_PrdMcNo
                    ) VALUES (
                        @RetCode, @RetDate, @RetMode, @RetTo, @StoreCode, @TotQty, @TotItm, @Remark, @RetType, 
                        @LocationTag, GETDATE(), @Username, 'New', 0, @IsGp, 0, @OperCode, ''
                    )";

                await conn.ExecuteAsync(sqlInsertHeader, new
                {
                    RetCode = retCode,
                    RetDate = request.RetDate.Date,
                    RetMode = string.IsNullOrWhiteSpace(request.RetMode) ? "From Department" : request.RetMode.Trim(),
                    RetTo = parsedRetTo,
                    StoreCode = request.StoreCode > 0 ? request.StoreCode : 1,
                    TotQty = totQty,
                    TotItm = totItm,
                    Remark = request.Remark ?? string.Empty,
                    RetType = retType,
                    LocationTag = locationTag,
                    Username = username,
                    IsGp = request.IsGp ? 1 : 0,
                    OperCode = parsedOper
                }, trans);

                // 7. Insert Lines into IssueRetDet & Increment Master Inventory in ITEMMST
                const string sqlInsertLine = @"
                    INSERT INTO IssueRetDet (
                        RetCode, I_Code, UOM, Ret_Cut, Rate, RetPcs, RetQty, Amt, kh_code, BinNo, 
                        IRD_MrgNo, Mat_Grade, Mat_Shade, Mat_Maker, Dept_Code, CUST_ID, isGP, 
                        CGPer, CGAmt, SGPer, SGAmt, IGPer, IGAmt, Net_Amt, Ret_Remark, RetCops, 
                        RCops_Type, IRD_HSN, IRD_ConvUOM, IRD_ConvQty
                    ) VALUES (
                        @RetCode, @ItemCode, @Uom, 0, @Rate, 0, @Qty, @Amt, @DivisionId, '', 
                        @MrgNo, @Grade, @Shade, @Maker, @DeptCode, @CustId, @IsGp, 
                        @CGPer, @CGAmt, @SGPer, @SGAmt, @IGPer, @IGAmt, @NetAmt, @Remark, @Cops, 
                        '', @Hsn, @Uom, 0
                    )";

                const string sqlIncrementItem = @"
                    UPDATE ITEMMST 
                    SET I_RQTY = I_RQTY + @Qty 
                    WHERE I_CODE = @ItemCode";

                foreach (var line in request.Lines)
                {
                    var uom = line.Uom > 0 ? line.Uom : (await conn.ExecuteScalarAsync<int?>("SELECT ISNULL(I_UOM, 1) FROM ITEMMST WHERE I_CODE = @ItemCode", new { ItemCode = line.ItemCode }, trans) ?? 1);
                    var amt = line.Amount > 0 ? line.Amount : (line.Amt > 0 ? line.Amt : Math.Round(line.Qty * line.Rate, 2));
                    var cgPer = line.CGPer > 0 ? line.CGPer : line.Cgst;
                    var sgPer = line.SGPer > 0 ? line.SGPer : line.Sgst;
                    var igPer = line.IGPer > 0 ? line.IGPer : line.Igst;
                    var cgAmt = line.CGAmt > 0 ? line.CGAmt : (line.CgstAmt > 0 ? line.CgstAmt : Math.Round(amt * (cgPer / 100.0), 2));
                    var sgAmt = line.SGAmt > 0 ? line.SGAmt : (line.SgstAmt > 0 ? line.SgstAmt : Math.Round(amt * (sgPer / 100.0), 2));
                    var igAmt = line.IGAmt > 0 ? line.IGAmt : (line.IgstAmt > 0 ? line.IgstAmt : Math.Round(amt * (igPer / 100.0), 2));
                    var netAmt = line.NetAmt > 0 ? line.NetAmt : (amt + cgAmt + sgAmt + igAmt);

                    await conn.ExecuteAsync(sqlInsertLine, new
                    {
                        RetCode = retCode,
                        ItemCode = line.ItemCode,
                        Uom = uom,
                        Rate = line.Rate,
                        Qty = line.Qty,
                        Amt = amt,
                        DivisionId = request.DivisionId > 0 ? request.DivisionId : 1,
                        MrgNo = line.MrgNo ?? string.Empty,
                        Grade = line.Grade ?? string.Empty,
                        Shade = line.Shade ?? string.Empty,
                        Maker = line.Maker ?? string.Empty,
                        DeptCode = parsedRetTo,
                        CustId = parsedRetTo,
                        IsGp = request.IsGp ? 1 : 0,
                        CGPer = cgPer,
                        CGAmt = cgAmt,
                        SGPer = sgPer,
                        SGAmt = sgAmt,
                        IGPer = igPer,
                        IGAmt = igAmt,
                        NetAmt = netAmt,
                        Remark = line.Remark ?? line.RetRemark ?? string.Empty,
                        Cops = line.Cops,
                        Hsn = line.Hsn ?? string.Empty
                    }, trans);

                    await conn.ExecuteAsync(sqlIncrementItem, new
                    {
                        Qty = line.Qty,
                        ItemCode = line.ItemCode
                    }, trans);
                }

                // 8. Delete previous stock register records (idempotent)
                const string sqlDeleteStock = "DELETE FROM stockregnew WHERE sr_code = @RetCode AND mode = 'IssueRet'";
                await conn.ExecuteAsync(sqlDeleteStock, new { RetCode = retCode }, trans);

                // 9. INSERT positive return stock movement into stockregnew (Mode = 'IssueRet', Priority = 12)
                const string sqlStockIncoming = @"
                    INSERT INTO stockregnew (
                        dt, I_Code, I_Qty, StkPcs, MrgNo, Mat_Grade, Mat_Shade, Priority, 
                        SR_Code, P_Name, Amt, SR_Stk, Mode, kh_Code, store_id, TYPEID, SR_SRNO, 
                        pr_id, stkcops, mat_unit, mat_other, Stk_DivID, PO_NO
                    ) 
                    SELECT 
                        RetDate as dt, 
                        I_Code, 
                        case when ird_convqty=0 or ird_convqty is null then ird.retqty else ird_convqty end*1 as I_Qty, 
                        RetPcs*1, 
                        ird_mrgno as mrgno, 
                        Mat_Grade, 
                        Mat_Shade, 
                        12 as Priority, 
                        IRD.RetCode as sr_code, 
                        ISNULL(lm.lab_name, ISNULL(pm.p_name, '')) as P_Name, 
                        round(rate*case when ird_convqty=0 or ird_convqty is null then ird.retqty else ird_convqty end*1, 2) as amt, 
                        'Y' as sr_stk, 
                        'IssueRet' as Mode, 
                        IRD.DEPT_CODE, 
                        IRM.STR_CODE, 
                        IRM.TYPEID, 
                        IRD.RETID, 
                        IRD.CUST_ID, 
                        ird.retcops, 
                        case when ird_convqty=0 or ird_convqty is null then ird.uom else ird_convuom end, 
                        ird.RCops_Type, 
                        ird.kh_code, 
                        IRM.RETMODE 
                    FROM IssueRetDet AS IRD 
                    left join IssueRetMst AS IRM ON IRD.RetCode = IRM.RetCode 
                    left join labourmst as lm on lm.lab_code = IRM.Ret_To 
                    left join partymst as pm on pm.p_code = IRM.ret_to 
                    where ird.retCode = @RetCode and IRM.RETDATE >= @FyStart";

                await conn.ExecuteAsync(sqlStockIncoming, new { RetCode = retCode, FyStart = fyStart }, trans);

                // 10. DAYBOOK Row #2 (Final audit confirmation)
                const string sqlDaybook2 = @"
                    INSERT INTO DAYBOOK (DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES (GETDATE(), @Username, @EntityName, @TotQty, @DocNo, 'NEW', 'RTN', 1, @CompanyName)";

                await conn.ExecuteAsync(sqlDaybook2, new
                {
                    Username = username,
                    EntityName = entityName ?? "RETURN",
                    TotQty = totQty,
                    DocNo = retCode,
                    CompanyName = companyName
                }, trans);

                trans.Commit();

                return new MaterialReturnSaveResultDto
                {
                    RetCode = retCode,
                    DocNo = retCode,
                    Success = true,
                    Message = $"Material return {retCode} saved successfully."
                };
            }
            catch (Exception ex)
            {
                trans.Rollback();
                _logger.LogError(ex, "Failed to create Material Return transaction.");
                throw;
            }
        }

        public async Task<MaterialReturnSaveResultDto> UpdateReturnAsync(
            string retCode, MaterialReturnCreateRequestDto request, string username, string locationTag, string companyName)
        {
            if (string.IsNullOrWhiteSpace(retCode)) throw new ArgumentException("Return code is required.", nameof(retCode));
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.Lines == null || request.Lines.Count == 0)
                throw new InvalidOperationException("Material return requires at least one line item.");

            using var conn = CreateConnection();
            await conn.OpenAsync();
            using var trans = conn.BeginTransaction(IsolationLevel.Serializable);

            try
            {
                // 1. Fetch existing header to verify existence and date lock
                const string sqlCheck = "SELECT RetCode, RetDate, TotQty, Ret_To FROM IssueRetMst WITH (UPDLOCK, HOLDLOCK) WHERE RetCode = @RetCode";
                var existing = await conn.QueryFirstOrDefaultAsync<dynamic>(sqlCheck, new { RetCode = retCode }, trans);
                if (existing == null)
                    throw new KeyNotFoundException($"Material return {retCode} not found.");

                DateTime oldDate = existing.RetDate;

                // Date Lock Verification
                const string sqlLock = "SELECT COUNT(1) FROM LOCKDATAMST WHERE LDM_STDT = @Date";
                var isOldLocked = (await conn.ExecuteScalarAsync<int>(sqlLock, new { Date = oldDate.Date }, trans)) > 0;
                if (isOldLocked)
                    throw new InvalidOperationException($"Original transaction date {oldDate:yyyy-MM-dd} is locked against financial modifications.");

                var isNewLocked = (await conn.ExecuteScalarAsync<int>(sqlLock, new { Date = request.RetDate.Date }, trans)) > 0;
                if (isNewLocked)
                    throw new InvalidOperationException($"New transaction date {request.RetDate:yyyy-MM-dd} is locked against financial modifications.");

                // 2. Read existing lines from IssueRetDet and reverse previously added stock in ITEMMST
                const string sqlOldLines = "SELECT I_Code AS ItemCode, RetQty FROM IssueRetDet WHERE RetCode = @RetCode";
                var oldLines = (await conn.QueryAsync<dynamic>(sqlOldLines, new { RetCode = retCode }, trans)).ToList();

                const string sqlReverseStock = @"
                    UPDATE ITEMMST 
                    SET I_RQTY = I_RQTY - @Qty 
                    WHERE I_CODE = @ItemCode";

                foreach (var oldLine in oldLines)
                {
                    double oldQty = (double)oldLine.RetQty;
                    string oldItemCode = (string)oldLine.ItemCode;

                    await conn.ExecuteAsync(sqlReverseStock, new
                    {
                        Qty = oldQty,
                        ItemCode = oldItemCode
                    }, trans);
                }

                // 3. Purge existing stock ledger rows in STOCKREGNEW
                const string sqlDeleteStock = "DELETE FROM stockregnew WHERE sr_code = @RetCode AND mode = 'IssueRet'";
                await conn.ExecuteAsync(sqlDeleteStock, new { RetCode = retCode }, trans);

                // 4. Delete existing lines from IssueRetDet
                const string sqlDeleteLines = "DELETE FROM IssueRetDet WHERE RetCode = @RetCode";
                await conn.ExecuteAsync(sqlDeleteLines, new { RetCode = retCode }, trans);

                // 5. Resolve Entity Name
                int parsedRetTo = int.TryParse(request.RetTo, out var rCode) ? rCode : 1;
                var entityName = request.RetToName;
                if (string.IsNullOrWhiteSpace(entityName))
                {
                    if (string.Equals(request.RetMode, "From Department", StringComparison.OrdinalIgnoreCase))
                    {
                        const string sqlDept = "SELECT LAB_NAME FROM LABOURMST WHERE LAB_CODE = @Code";
                        entityName = await conn.ExecuteScalarAsync<string>(sqlDept, new { Code = parsedRetTo }, trans);
                    }
                    else
                    {
                        const string sqlParty = "SELECT P_NAME FROM PARTYMST WHERE P_CODE = @Code";
                        entityName = await conn.ExecuteScalarAsync<string>(sqlParty, new { Code = parsedRetTo }, trans);
                    }
                }

                int parsedOper = int.TryParse(request.OperatorCode, out var opCode) ? opCode : (request.OperCode > 0 ? request.OperCode : 1);
                string retType = !string.IsNullOrWhiteSpace(request.Source) ? request.Source.Trim() : (!string.IsNullOrWhiteSpace(request.RetType) ? request.RetType.Trim() : "Direct");

                // 6. Update master header in IssueRetMst
                double totQty = request.Lines.Sum(l => l.Qty);
                int totItm = request.Lines.Count;

                const string sqlUpdateHeader = @"
                    UPDATE IssueRetMst SET 
                        RetDate = @RetDate, 
                        RetMode = @RetMode, 
                        Ret_To = @RetTo, 
                        Str_Code = @StoreCode, 
                        TotQty = @TotQty, 
                        TotItm = @TotItm, 
                        remark = @Remark, 
                        RetType = @RetType, 
                        IRM_UsrName = @Username, 
                        IRM_EDate = GETDATE(), 
                        IRM_EMode = 'Update', 
                        isGP = @IsGp, 
                        Rec_OperCode = @OperCode 
                    WHERE RetCode = @RetCode";

                await conn.ExecuteAsync(sqlUpdateHeader, new
                {
                    RetCode = retCode,
                    RetDate = request.RetDate.Date,
                    RetMode = string.IsNullOrWhiteSpace(request.RetMode) ? "From Department" : request.RetMode.Trim(),
                    RetTo = parsedRetTo,
                    StoreCode = request.StoreCode > 0 ? request.StoreCode : 1,
                    TotQty = totQty,
                    TotItm = totItm,
                    Remark = request.Remark ?? string.Empty,
                    RetType = retType,
                    Username = username,
                    IsGp = request.IsGp ? 1 : 0,
                    OperCode = parsedOper
                }, trans);

                // 7. Insert updated lines into IssueRetDet & Increment ITEMMST
                const string sqlInsertLine = @"
                    INSERT INTO IssueRetDet (
                        RetCode, I_Code, UOM, Ret_Cut, Rate, RetPcs, RetQty, Amt, kh_code, BinNo, 
                        IRD_MrgNo, Mat_Grade, Mat_Shade, Mat_Maker, Dept_Code, CUST_ID, isGP, 
                        CGPer, CGAmt, SGPer, SGAmt, IGPer, IGAmt, Net_Amt, Ret_Remark, RetCops, 
                        RCops_Type, IRD_HSN, IRD_ConvUOM, IRD_ConvQty
                    ) VALUES (
                        @RetCode, @ItemCode, @Uom, 0, @Rate, 0, @Qty, @Amt, @DivisionId, '', 
                        @MrgNo, @Grade, @Shade, @Maker, @DeptCode, @CustId, @IsGp, 
                        @CGPer, @CGAmt, @SGPer, @SGAmt, @IGPer, @IGAmt, @NetAmt, @Remark, @Cops, 
                        '', @Hsn, @Uom, 0
                    )";

                const string sqlIncrementItem = @"
                    UPDATE ITEMMST 
                    SET I_RQTY = I_RQTY + @Qty 
                    WHERE I_CODE = @ItemCode";

                foreach (var line in request.Lines)
                {
                    var uom = line.Uom > 0 ? line.Uom : (await conn.ExecuteScalarAsync<int?>("SELECT ISNULL(I_UOM, 1) FROM ITEMMST WHERE I_CODE = @ItemCode", new { ItemCode = line.ItemCode }, trans) ?? 1);
                    var amt = line.Amount > 0 ? line.Amount : (line.Amt > 0 ? line.Amt : Math.Round(line.Qty * line.Rate, 2));
                    var cgPer = line.CGPer > 0 ? line.CGPer : line.Cgst;
                    var sgPer = line.SGPer > 0 ? line.SGPer : line.Sgst;
                    var igPer = line.IGPer > 0 ? line.IGPer : line.Igst;
                    var cgAmt = line.CGAmt > 0 ? line.CGAmt : (line.CgstAmt > 0 ? line.CgstAmt : Math.Round(amt * (cgPer / 100.0), 2));
                    var sgAmt = line.SGAmt > 0 ? line.SGAmt : (line.SgstAmt > 0 ? line.SgstAmt : Math.Round(amt * (sgPer / 100.0), 2));
                    var igAmt = line.IGAmt > 0 ? line.IGAmt : (line.IgstAmt > 0 ? line.IgstAmt : Math.Round(amt * (igPer / 100.0), 2));
                    var netAmt = line.NetAmt > 0 ? line.NetAmt : (amt + cgAmt + sgAmt + igAmt);

                    await conn.ExecuteAsync(sqlInsertLine, new
                    {
                        RetCode = retCode,
                        ItemCode = line.ItemCode,
                        Uom = uom,
                        Rate = line.Rate,
                        Qty = line.Qty,
                        Amt = amt,
                        DivisionId = request.DivisionId > 0 ? request.DivisionId : 1,
                        MrgNo = line.MrgNo ?? string.Empty,
                        Grade = line.Grade ?? string.Empty,
                        Shade = line.Shade ?? string.Empty,
                        Maker = line.Maker ?? string.Empty,
                        DeptCode = parsedRetTo,
                        CustId = parsedRetTo,
                        IsGp = request.IsGp ? 1 : 0,
                        CGPer = cgPer,
                        CGAmt = cgAmt,
                        SGPer = sgPer,
                        SGAmt = sgAmt,
                        IGPer = igPer,
                        IGAmt = igAmt,
                        NetAmt = netAmt,
                        Remark = line.Remark ?? line.RetRemark ?? string.Empty,
                        Cops = line.Cops,
                        Hsn = line.Hsn ?? string.Empty
                    }, trans);

                    await conn.ExecuteAsync(sqlIncrementItem, new
                    {
                        Qty = line.Qty,
                        ItemCode = line.ItemCode
                    }, trans);
                }

                // 8. Re-insert positive return into stockregnew
                var (fyStart, _, _) = GetFinancialYearBounds(request.RetDate);

                const string sqlStockIncoming = @"
                    INSERT INTO stockregnew (
                        dt, I_Code, I_Qty, StkPcs, MrgNo, Mat_Grade, Mat_Shade, Priority, 
                        SR_Code, P_Name, Amt, SR_Stk, Mode, kh_Code, store_id, TYPEID, SR_SRNO, 
                        pr_id, stkcops, mat_unit, mat_other, Stk_DivID, PO_NO
                    ) 
                    SELECT 
                        RetDate as dt, 
                        I_Code, 
                        case when ird_convqty=0 or ird_convqty is null then ird.retqty else ird_convqty end*1 as I_Qty, 
                        RetPcs*1, 
                        ird_mrgno as mrgno, 
                        Mat_Grade, 
                        Mat_Shade, 
                        12 as Priority, 
                        IRD.RetCode as sr_code, 
                        ISNULL(lm.lab_name, ISNULL(pm.p_name, '')) as P_Name, 
                        round(rate*case when ird_convqty=0 or ird_convqty is null then ird.retqty else ird_convqty end*1, 2) as amt, 
                        'Y' as sr_stk, 
                        'IssueRet' as Mode, 
                        IRD.DEPT_CODE, 
                        IRM.STR_CODE, 
                        IRM.TYPEID, 
                        IRD.RETID, 
                        IRD.CUST_ID, 
                        ird.retcops, 
                        case when ird_convqty=0 or ird_convqty is null then ird.uom else ird_convuom end, 
                        ird.RCops_Type, 
                        ird.kh_code, 
                        IRM.RETMODE 
                    FROM IssueRetDet AS IRD 
                    left join IssueRetMst AS IRM ON IRD.RetCode = IRM.RetCode 
                    left join labourmst as lm on lm.lab_code = IRM.Ret_To 
                    left join partymst as pm on pm.p_code = IRM.ret_to 
                    where ird.retCode = @RetCode and IRM.RETDATE >= @FyStart";

                await conn.ExecuteAsync(sqlStockIncoming, new { RetCode = retCode, FyStart = fyStart }, trans);

                // 9. DAYBOOK audit entry for UPDATE
                const string sqlDaybook = @"
                    INSERT INTO DAYBOOK (DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES (GETDATE(), @Username, @EntityName, @TotQty, @DocNo, 'UPDATE', 'RTN', 1, @CompanyName)";

                await conn.ExecuteAsync(sqlDaybook, new
                {
                    Username = username,
                    EntityName = entityName ?? "RETURN",
                    TotQty = totQty,
                    DocNo = retCode,
                    CompanyName = companyName
                }, trans);

                trans.Commit();

                return new MaterialReturnSaveResultDto
                {
                    RetCode = retCode,
                    DocNo = retCode,
                    Success = true,
                    Message = $"Material return {retCode} updated successfully."
                };
            }
            catch (Exception ex)
            {
                trans.Rollback();
                _logger.LogError(ex, "Failed to update Material Return transaction {RetCode}.", retCode);
                throw;
            }
        }

        public async Task<MaterialReturnSaveResultDto> DeleteReturnAsync(string retCode, string username, string companyName)
        {
            if (string.IsNullOrWhiteSpace(retCode)) throw new ArgumentException("Return code is required.", nameof(retCode));

            using var conn = CreateConnection();
            await conn.OpenAsync();
            using var trans = conn.BeginTransaction(IsolationLevel.Serializable);

            try
            {
                // 1. Fetch existing header
                const string sqlCheck = "SELECT RetCode, RetDate, TotQty, Ret_To, RetMode FROM IssueRetMst WITH (UPDLOCK, HOLDLOCK) WHERE RetCode = @RetCode";
                var existing = await conn.QueryFirstOrDefaultAsync<dynamic>(sqlCheck, new { RetCode = retCode }, trans);
                if (existing == null)
                    throw new KeyNotFoundException($"Material return {retCode} not found.");

                DateTime retDate = existing.RetDate;
                double totQty = (double)(existing.TotQty ?? 0.0);
                int retTo = (int)(existing.Ret_To ?? 0);
                string retMode = (string)(existing.RetMode ?? "From Department");

                // 2. Date Lock Verification
                const string sqlLock = "SELECT COUNT(1) FROM LOCKDATAMST WHERE LDM_STDT = @Date";
                var isLocked = (await conn.ExecuteScalarAsync<int>(sqlLock, new { Date = retDate.Date }, trans)) > 0;
                if (isLocked)
                    throw new InvalidOperationException($"Transaction date {retDate:yyyy-MM-dd} is locked against financial deletion.");

                // 3. Read lines and reverse added inventory in ITEMMST
                const string sqlLines = "SELECT I_Code AS ItemCode, RetQty FROM IssueRetDet WHERE RetCode = @RetCode";
                var lines = (await conn.QueryAsync<dynamic>(sqlLines, new { RetCode = retCode }, trans)).ToList();

                const string sqlReverseStock = @"
                    UPDATE ITEMMST 
                    SET I_RQTY = I_RQTY - @Qty 
                    WHERE I_CODE = @ItemCode";

                foreach (var line in lines)
                {
                    double qty = (double)line.RetQty;
                    string itemCode = (string)line.ItemCode;

                    await conn.ExecuteAsync(sqlReverseStock, new
                    {
                        Qty = qty,
                        ItemCode = itemCode
                    }, trans);
                }

                // 4. Purge STOCKREGNEW
                const string sqlDeleteStock = "DELETE FROM stockregnew WHERE sr_code = @RetCode AND mode = 'IssueRet'";
                await conn.ExecuteAsync(sqlDeleteStock, new { RetCode = retCode }, trans);

                // 5. Delete IssueRetDet
                const string sqlDeleteLines = "DELETE FROM IssueRetDet WHERE RetCode = @RetCode";
                await conn.ExecuteAsync(sqlDeleteLines, new { RetCode = retCode }, trans);

                // 6. Delete IssueRetMst
                const string sqlDeleteHeader = "DELETE FROM IssueRetMst WHERE RetCode = @RetCode";
                await conn.ExecuteAsync(sqlDeleteHeader, new { RetCode = retCode }, trans);

                // Resolve entity name for audit
                string? entityName = null;
                if (string.Equals(retMode, "From Department", StringComparison.OrdinalIgnoreCase))
                {
                    const string sqlDept = "SELECT LAB_NAME FROM LABOURMST WHERE LAB_CODE = @Code";
                    entityName = await conn.ExecuteScalarAsync<string>(sqlDept, new { Code = retTo }, trans);
                }
                else
                {
                    const string sqlParty = "SELECT P_NAME FROM PARTYMST WHERE P_CODE = @Code";
                    entityName = await conn.ExecuteScalarAsync<string>(sqlParty, new { Code = retTo }, trans);
                }

                // 7. DAYBOOK row for DELETE
                const string sqlDaybook = @"
                    INSERT INTO DAYBOOK (DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES (GETDATE(), @Username, @EntityName, @TotQty, @DocNo, 'DELETE', 'RTN', 1, @CompanyName)";

                await conn.ExecuteAsync(sqlDaybook, new
                {
                    Username = username,
                    EntityName = entityName ?? "RETURN",
                    TotQty = totQty,
                    DocNo = retCode,
                    CompanyName = companyName
                }, trans);

                trans.Commit();

                return new MaterialReturnSaveResultDto
                {
                    RetCode = retCode,
                    Success = true,
                    Message = $"Material return {retCode} deleted and inventory restored successfully."
                };
            }
            catch (Exception ex)
            {
                trans.Rollback();
                _logger.LogError(ex, "Failed to delete Material Return {RetCode}.", retCode);
                throw;
            }
        }
    }
}
