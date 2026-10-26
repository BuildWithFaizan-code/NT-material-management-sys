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
    public class IndentRepository : IIndentRepository
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<IndentRepository> _logger;

        public IndentRepository(IConfiguration configuration, ILogger<IndentRepository> logger)
        {
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        private IDbConnection CreateConnection()
        {
            var connStr = DbConnectionHelper.ResolveConnectionString(_configuration);
            return new SqlConnection(connStr);
        }

        public async Task<IndentLookupsDto> GetLookupsAsync()
        {
            using var conn = CreateConnection();

            const string deptsSql = @"
                SELECT LAB_CODE AS LabCode, LAB_NAME AS LabName 
                FROM LABOURMST 
                WHERE (LAB_STATUS = '' OR LAB_STATUS IS NULL OR LAB_STATUS = 'YES') 
                ORDER BY LAB_NAME;";

            const string storesSql = @"
                SELECT STR_CODE AS StrCode, STR_NAME AS StrName 
                FROM STOREMST 
                WHERE STR_NAME <> '' 
                ORDER BY STR_NAME;";

            const string capModesSql = @"
                SELECT DISTINCT LOC_CODE AS LocCode, LOCATION AS Location 
                FROM LOCATIONMST 
                WHERE MODE = 'CAPCONS' 
                ORDER BY LOCATION;";

            var departments = (await conn.QueryAsync<IndentDepartmentLookupDto>(deptsSql)).ToList();
            var stores = (await conn.QueryAsync<IndentStoreLookupDto>(storesSql)).ToList();
            var capModes = (await conn.QueryAsync<IndentCapModeLookupDto>(capModesSql)).ToList();

            var previewDate = await conn.ExecuteScalarAsync<DateTime>("SELECT GETDATE();");
            var nextIndNo = await GenerateNextIndentNumberInternalAsync(conn, null, previewDate);

            return new IndentLookupsDto
            {
                NextIndNo = nextIndNo,
                Departments = departments,
                Stores = stores,
                CapModes = capModes,
                Priorities = new List<string> { "Normal", "High", "Urgent" },
                Sources = new List<string> { "Manual" }
            };
        }

        public async Task<List<IndentCostCenterLookupDto>> GetCostCentersByStoreAsync(int storeCode)
        {
            const string sql = @"
                SELECT KH_NAME AS KhName, KH_CODE AS KhCode 
                FROM KHATAMST 
                CROSS APPLY DBO.FNSPLITSTRING(KH_BRANCH, ',') 
                WHERE KH_NAME <> '' 
                  AND (KH_DISPLAY IS NULL OR KH_DISPLAY = 0) 
                  AND SPLITDATA = @StoreCodeStr 
                ORDER BY KH_NAME;";

            using var conn = CreateConnection();
            var list = await conn.QueryAsync<IndentCostCenterLookupDto>(sql, new { StoreCodeStr = storeCode.ToString() });
            return list.ToList();
        }

        public async Task<IndentPagedResult<IndentItemLookupDto>> SearchItemsAsync(string? search, int page, int pageSize)
        {
            var cleanSearch = search?.Trim() ?? string.Empty;
            var safePage = page < 1 ? 1 : page;
            var safePageSize = pageSize < 1 ? 25 : (pageSize > 150 ? 150 : pageSize);
            var offset = (safePage - 1) * safePageSize;

            const string countSql = @"
                SELECT COUNT(1) 
                FROM ITEMMST AS IM 
                WHERE (IM.I_BLOCK IS NULL OR IM.I_BLOCK = 0) 
                  AND IM.I_HSN <> '' 
                  AND (@Search = '' OR IM.I_CODE LIKE '%' + @Search + '%' OR IM.I_NAME1 LIKE '%' + @Search + '%');";

            const string dataSql = @"
                SELECT IM.I_CODE AS ICode, IM.I_NAME1 AS ItName, 
                       ISNULL(UM.UNIT_CODE, 0) AS UnitCode, ISNULL(UM.UNIT_NAME, '') AS UnitName,
                       CAST(ISNULL(IM.I_RQTY, 0) AS DECIMAL(18,3)) AS Stk, 
                       CAST(ISNULL(IM.I_YARN5, 0) AS DECIMAL(18,3)) AS MinQty, 
                       CAST(ISNULL(IM.I_YARN6, 0) AS DECIMAL(18,3)) AS MaxQty, 
                       CAST(ISNULL(IM.I_REQTY, 0) AS DECIMAL(18,3)) AS OrderOn,
                       '' AS ReqCode
                FROM ITEMMST AS IM 
                LEFT JOIN UNITMST AS UM ON IM.I_UOM = UM.UNIT_CODE 
                WHERE (IM.I_BLOCK IS NULL OR IM.I_BLOCK = 0) 
                  AND IM.I_HSN <> '' 
                  AND (@Search = '' OR IM.I_CODE LIKE '%' + @Search + '%' OR IM.I_NAME1 LIKE '%' + @Search + '%')
                ORDER BY IM.I_CODE, IM.I_NAME1
                OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;";

            using var conn = CreateConnection();
            var totalCount = await conn.ExecuteScalarAsync<int>(countSql, new { Search = cleanSearch });
            var items = (await conn.QueryAsync<IndentItemLookupDto>(dataSql, new { Search = cleanSearch, Offset = offset, PageSize = safePageSize })).ToList();

            return new IndentPagedResult<IndentItemLookupDto>
            {
                Items = items,
                TotalCount = totalCount,
                Page = safePage,
                PageSize = safePageSize
            };
        }

        public async Task<List<string>> GetRemarkSuggestionsAsync(string query)
        {
            var cleanQuery = query?.Trim() ?? string.Empty;
            const string sql = @"
                SELECT TOP 10 REMARK 
                FROM INDENT_MASTER 
                WHERE REMARK IS NOT NULL AND REMARK <> '' 
                  AND (@Query = '' OR REMARK LIKE @Query + '%')
                GROUP BY REMARK 
                ORDER BY REMARK;";

            using var conn = CreateConnection();
            var list = await conn.QueryAsync<string>(sql, new { Query = cleanQuery });
            return list.ToList();
        }

        public async Task<bool> IsDateLockedAsync(DateTime date)
        {
            const string sql = "SELECT COUNT(1) FROM LOCKDATAMST WHERE CAST(@Date AS DATE) = CAST(LDM_STDT AS DATE);";
            using var conn = CreateConnection();
            var count = await conn.ExecuteScalarAsync<int>(sql, new { Date = date.Date });
            return count > 0;
        }

        public async Task<IndentPagedResult<IndentHeaderDto>> GetIndentsAsync(IndentFilterRequest filter)
        {
            var req = filter ?? new IndentFilterRequest();
            var search = req.Search?.Trim() ?? string.Empty;
            var safePage = req.Page < 1 ? 1 : req.Page;
            var safePageSize = req.PageSize < 1 ? 25 : req.PageSize;
            var offset = (safePage - 1) * safePageSize;

            const string countSql = @"
                SELECT COUNT(1)
                FROM INDENT_MASTER A
                LEFT JOIN LABOURMST B ON A.Dept_Code = B.LAB_CODE
                LEFT JOIN STOREMST C ON A.Store_Code = C.STR_CODE
                WHERE (@Search = '' OR A.Ind_code LIKE '%' + @Search + '%' OR B.LAB_NAME LIKE '%' + @Search + '%' OR C.STR_NAME LIKE '%' + @Search + '%' OR A.Remark LIKE '%' + @Search + '%')
                  AND (@FromDate IS NULL OR A.Ind_Date >= @FromDate)
                  AND (@ToDate IS NULL OR A.Ind_Date <= @ToDate);";

            const string dataSql = @"
                SELECT A.Ind_code AS IndCode, A.Ind_Date AS IndDate, 
                       A.Dept_Code AS DeptCode, ISNULL(B.LAB_NAME, '') AS DeptName, 
                       A.Store_Code AS StoreCode, ISNULL(C.STR_NAME, '') AS StoreName, 
                       ISNULL(A.Priority, 'Normal') AS Priority, ISNULL(A.Source, 'Manual') AS Source, 
                       ISNULL(A.Tot_Item, 0) AS TotItem, ISNULL(A.Tot_Qty, 0) AS TotQty, ISNULL(A.Tot_Amt, 0) AS TotAmt, 
                       ISNULL(A.Remark, '') AS Remark, 
                       ISNULL(A.IsAppro, 0) AS IsAppro, A.AppDate, 
                       ISNULL(A.Ind_UsrName, '') AS IndUsrName, ISNULL(A.Ind_EMode, 'New') AS IndEMode, 
                       ISNULL(A.Ind_CapMode, 0) AS IndCapMode, ISNULL(L.LOCATION, '') AS CapModeName,
                       ISNULL(A.TYPEID, 0) AS TypeId
                FROM INDENT_MASTER A
                LEFT JOIN LABOURMST B ON A.Dept_Code = B.LAB_CODE
                LEFT JOIN STOREMST C ON A.Store_Code = C.STR_CODE
                LEFT JOIN LOCATIONMST L ON A.Ind_CapMode = L.LOC_CODE
                WHERE (@Search = '' OR A.Ind_code LIKE '%' + @Search + '%' OR B.LAB_NAME LIKE '%' + @Search + '%' OR C.STR_NAME LIKE '%' + @Search + '%' OR A.Remark LIKE '%' + @Search + '%')
                  AND (@FromDate IS NULL OR A.Ind_Date >= @FromDate)
                  AND (@ToDate IS NULL OR A.Ind_Date <= @ToDate)
                ORDER BY A.Ind_Date DESC, A.Ind_code DESC
                OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;";

            using var conn = CreateConnection();
            var totalCount = await conn.ExecuteScalarAsync<int>(countSql, new
            {
                Search = search,
                FromDate = req.FromDate,
                ToDate = req.ToDate
            });

            var items = (await conn.QueryAsync<IndentHeaderDto>(dataSql, new
            {
                Search = search,
                FromDate = req.FromDate,
                ToDate = req.ToDate,
                Offset = offset,
                PageSize = safePageSize
            })).ToList();

            return new IndentPagedResult<IndentHeaderDto>
            {
                Items = items,
                TotalCount = totalCount,
                Page = safePage,
                PageSize = safePageSize
            };
        }

        public async Task<IndentHeaderDto?> GetIndentByCodeAsync(string indCode)
        {
            if (string.IsNullOrWhiteSpace(indCode)) return null;

            const string headerSql = @"
                SELECT A.Ind_code AS IndCode, A.Ind_Date AS IndDate, 
                       A.Dept_Code AS DeptCode, ISNULL(B.LAB_NAME, '') AS DeptName, 
                       A.Store_Code AS StoreCode, ISNULL(C.STR_NAME, '') AS StoreName, 
                       ISNULL(A.Priority, 'Normal') AS Priority, ISNULL(A.Source, 'Manual') AS Source, 
                       ISNULL(A.Tot_Item, 0) AS TotItem, ISNULL(A.Tot_Qty, 0) AS TotQty, ISNULL(A.Tot_Amt, 0) AS TotAmt, 
                       ISNULL(A.Remark, '') AS Remark, 
                       ISNULL(A.IsAppro, 0) AS IsAppro, A.AppDate, 
                       ISNULL(A.Ind_UsrName, '') AS IndUsrName, ISNULL(A.Ind_EMode, 'New') AS IndEMode, 
                       ISNULL(A.Ind_CapMode, 0) AS IndCapMode, ISNULL(L.LOCATION, '') AS CapModeName,
                       ISNULL(A.TYPEID, 0) AS TypeId
                FROM INDENT_MASTER A
                LEFT JOIN LABOURMST B ON A.Dept_Code = B.LAB_CODE
                LEFT JOIN STOREMST C ON A.Store_Code = C.STR_CODE
                LEFT JOIN LOCATIONMST L ON A.Ind_CapMode = L.LOC_CODE
                WHERE A.Ind_code = @IndCode;";

            const string itemsSql = @"
                SELECT D.Ind_code AS IndCode, D.srNo AS Srno, D.ReqNo AS ReqNo, 
                       D.Code AS Code, ISNULL(I.I_NAME1, '') AS ItemName, 
                       D.uom AS Uom, ISNULL(U.UNIT_NAME, '') AS UomName, 
                       D.qty AS Qty, D.Rate AS Rate, D.totalValue AS TotalValue, 
                       D.KH_Code AS KhCode, ISNULL(K.KH_NAME, '') AS CostCenterName, 
                       D.Dept_code AS DeptCode, ISNULL(L.LAB_NAME, '') AS DeptName, 
                       D.ReqDate AS ReqDate, ISNULL(D.ISAppro, 0) AS IsAppro
                FROM indent_det D
                LEFT JOIN ITEMMST I ON D.Code = I.I_CODE
                LEFT JOIN UNITMST U ON D.uom = U.UNIT_CODE
                LEFT JOIN KHATAMST K ON D.KH_Code = K.KH_CODE
                LEFT JOIN LABOURMST L ON D.Dept_code = L.LAB_CODE
                WHERE D.Ind_code = @IndCode
                ORDER BY D.srNo;";

            using var conn = CreateConnection();
            var header = await conn.QueryFirstOrDefaultAsync<IndentHeaderDto>(headerSql, new { IndCode = indCode.Trim() });
            if (header == null) return null;

            var items = (await conn.QueryAsync<IndentDetailDto>(itemsSql, new { IndCode = indCode.Trim() })).ToList();
            header.Items = items;
            return header;
        }

        private async Task<string> GenerateNextIndentNumberInternalAsync(IDbConnection conn, IDbTransaction? tx, DateTime entryDate)
        {
            var locationTag = CompanyConfigHelper.ResolveLocationCode(_configuration);

            var fyStartYear = entryDate.Month >= 4 ? entryDate.Year : entryDate.Year - 1;
            var fyStart = new DateTime(fyStartYear, 4, 1);
            var fyEnd = new DateTime(fyStartYear + 1, 3, 31, 23, 59, 59);
            var fySuffix = ((fyStartYear + 1) % 100).ToString("D2");

            var lockHint = tx != null ? "WITH (UPDLOCK, HOLDLOCK)" : "WITH (NOLOCK)";
            var maxSql = $@"
                SELECT ISNULL(MAX(TRY_CAST(SUBSTRING(IND_CODE, 6, 6) AS INT)), 0) 
                FROM INDENT_MASTER {lockHint}
                WHERE IND_LOC = @LocationTag 
                  AND IND_DATE >= @FyStart 
                  AND IND_DATE <= @FyEnd 
                  AND LEFT(IND_CODE, 4) = 'INDE';";

            var maxNum = await conn.ExecuteScalarAsync<int>(maxSql, new
            {
                LocationTag = locationTag,
                FyStart = fyStart,
                FyEnd = fyEnd
            }, tx);

            var nextNum = maxNum + 1;
            return $"INDE/{nextNum:D6}/{fySuffix}";
        }

        public async Task<string> SaveIndentAsync(IndentSaveRequest request, string username)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.Items == null || request.Items.Count == 0)
            {
                throw new InvalidOperationException("At least one line item is required to save an Indent.");
            }
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Authenticated user identity is required for audit logging.", nameof(username));
            }

            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);
            var locationTag = CompanyConfigHelper.ResolveLocationCode(_configuration);

            using var conn = CreateConnection();
            if (conn.State != ConnectionState.Open) conn.Open();
            using var tx = conn.BeginTransaction(IsolationLevel.Serializable);

            try
            {
                // 1. Lock Date validation
                const string lockCheckSql = @"
                    SELECT COUNT(1) 
                    FROM LOCKDATAMST 
                    WHERE CAST(@IndDate AS DATE) = CAST(LDM_STDT AS DATE);";

                var isLocked = (await conn.ExecuteScalarAsync<int>(lockCheckSql, new { IndDate = request.IndDate.Date }, tx)) > 0;
                if (isLocked)
                {
                    throw new InvalidOperationException($"The transaction date '{request.IndDate:yyyy-MM-dd}' is locked by administrative control. Cannot save Indent.");
                }

                // 2. Resolve Department Name for DAYBOOK audit
                const string deptNameSql = "SELECT TOP 1 LAB_NAME FROM LABOURMST WHERE LAB_CODE = @DeptCode;";
                var deptName = await conn.ExecuteScalarAsync<string>(deptNameSql, new { DeptCode = request.DeptCode }, tx);
                deptName = string.IsNullOrWhiteSpace(deptName) ? "REGULAR" : deptName.Trim();

                // 3. Atomically generate next sequential document number
                var indCode = await GenerateNextIndentNumberInternalAsync(conn, tx, request.IndDate);

                // 4. Calculate header totals
                var totItem = (short)request.Items.Count;
                var totQty = request.Items.Sum(x => x.Qty);
                var totAmt = request.Items.Sum(x => x.TotalValue);

                // 5. Insert INDENT_MASTER header
                const string insertHeaderSql = @"
                    INSERT INTO Indent_Master (
                        Ind_Code, Ind_Date, Dept_code, Store_Code, Priority, Source, 
                        Tot_Item, Tot_qty, Tot_Amt, Remark, IND_LOC, Ind_EDate, 
                        Ind_UsrName, Ind_EMode, Ind_CapMode, TypeID, isEnq
                    ) VALUES (
                        @IndCode, @IndDate, @DeptCode, @StoreCode, @Priority, @Source, 
                        @TotItem, @TotQty, @TotAmt, @Remark, @LocationTag, GETDATE(), 
                        @Username, 'New', @CapMode, 0, 0
                    );";

                await conn.ExecuteAsync(insertHeaderSql, new
                {
                    IndCode = indCode,
                    IndDate = request.IndDate,
                    DeptCode = request.DeptCode,
                    StoreCode = request.StoreCode,
                    Priority = string.IsNullOrWhiteSpace(request.Priority) ? "Normal" : request.Priority.Trim(),
                    Source = string.IsNullOrWhiteSpace(request.Source) ? "Manual" : request.Source.Trim(),
                    TotItem = totItem,
                    TotQty = totQty,
                    TotAmt = totAmt,
                    Remark = request.Remark?.Trim() ?? string.Empty,
                    LocationTag = locationTag,
                    Username = username.Trim(),
                    CapMode = request.CapMode
                }, tx);

                // 6. Insert INDENT_DET line items
                const string insertLineSql = @"
                    INSERT INTO indent_det (
                        Ind_Code, reqNo, Srno, Code, Description, uom, qty, Rate, 
                        totalValue, KH_Code, Dept_code, ReqDate, inq, isEnq
                    ) VALUES (
                        @IndCode, @ReqNo, @Srno, @Code, @Description, @Uom, @Qty, @Rate, 
                        @TotalValue, @KhCode, @DeptCode, @ReqDate, 0, 0
                    );";

                for (var i = 0; i < request.Items.Count; i++)
                {
                    var item = request.Items[i];
                    var reqNo = string.IsNullOrWhiteSpace(item.ReqNo) ? "None" : item.ReqNo.Trim();
                    var lineDept = item.DeptCode > 0 ? item.DeptCode : request.DeptCode;
                    var reqDate = item.ReqDate != default ? item.ReqDate : request.IndDate;

                    await conn.ExecuteAsync(insertLineSql, new
                    {
                        IndCode = indCode,
                        ReqNo = reqNo,
                        Srno = i, // 0-indexed per trace
                        Code = item.Code.Trim(),
                        Description = item.Description?.Trim() ?? string.Empty,
                        Uom = item.Uom,
                        Qty = item.Qty,
                        Rate = item.Rate,
                        TotalValue = item.TotalValue,
                        KhCode = item.KhCode,
                        DeptCode = lineDept,
                        ReqDate = reqDate
                    }, tx);

                    // 6b. Update Requisition_Master if linked to a requisition
                    if (!string.IsNullOrWhiteSpace(reqNo) && !reqNo.Equals("None", StringComparison.OrdinalIgnoreCase))
                    {
                        const string updateReqSql = @"
                            UPDATE Requisition_Master 
                            SET IsInd = 'Indent', IndDate = @IndDate 
                            WHERE Req_Code = @ReqNo;";
                        await conn.ExecuteAsync(updateReqSql, new { IndDate = request.IndDate, ReqNo = reqNo }, tx);
                    }
                }

                // 7. Insert DAYBOOK audit log
                // DB_AMT = Tot_qty (per legacy trace sample), DB_TYP = 'IDT', DB_ACTION = 'NEW'
                const string insertDaybookSql = @"
                    INSERT INTO DAYBOOK (
                        DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME
                    ) VALUES (
                        GETDATE(), @Username, @DeptName, @TotQty, @IndCode, 'NEW', 'IDT', 1, @CompanyName
                    );";

                await conn.ExecuteAsync(insertDaybookSql, new
                {
                    Username = username.Trim(),
                    DeptName = deptName,
                    TotQty = totQty,
                    IndCode = indCode,
                    CompanyName = companyName
                }, tx);

                tx.Commit();
                _logger.LogInformation("Successfully created Indent {IndCode} with {Count} item(s) by user {User}", indCode, totItem, username);
                return indCode;
            }
            catch (Exception ex)
            {
                tx.Rollback();
                _logger.LogError(ex, "Transaction aborted and rolled back during Indent creation by user {User}", username);
                throw;
            }
        }

        public async Task<string> UpdateIndentAsync(string indCode, IndentSaveRequest request, string username)
        {
            if (string.IsNullOrWhiteSpace(indCode)) throw new ArgumentException("Indent code is required.", nameof(indCode));
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.Items == null || request.Items.Count == 0)
            {
                throw new InvalidOperationException("At least one line item is required to update an Indent.");
            }

            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);
            var locationTag = CompanyConfigHelper.ResolveLocationCode(_configuration);

            using var conn = CreateConnection();
            if (conn.State != ConnectionState.Open) conn.Open();
            using var tx = conn.BeginTransaction(IsolationLevel.Serializable);

            try
            {
                // 1. Lock Date validation
                const string lockCheckSql = @"
                    SELECT COUNT(1) 
                    FROM LOCKDATAMST 
                    WHERE CAST(@IndDate AS DATE) = CAST(LDM_STDT AS DATE);";

                var isLocked = (await conn.ExecuteScalarAsync<int>(lockCheckSql, new { IndDate = request.IndDate.Date }, tx)) > 0;
                if (isLocked)
                {
                    throw new InvalidOperationException($"The transaction date '{request.IndDate:yyyy-MM-dd}' is locked by administrative control. Cannot update Indent.");
                }

                // 2. Verify Indent exists
                const string checkExistsSql = "SELECT COUNT(1) FROM Indent_Master WHERE Ind_Code = @IndCode;";
                var exists = (await conn.ExecuteScalarAsync<int>(checkExistsSql, new { IndCode = indCode.Trim() }, tx)) > 0;
                if (!exists)
                {
                    throw new KeyNotFoundException($"Indent '{indCode}' was not found.");
                }

                // 3. Resolve Department Name
                const string deptNameSql = "SELECT TOP 1 LAB_NAME FROM LABOURMST WHERE LAB_CODE = @DeptCode;";
                var deptName = await conn.ExecuteScalarAsync<string>(deptNameSql, new { DeptCode = request.DeptCode }, tx);
                deptName = string.IsNullOrWhiteSpace(deptName) ? "REGULAR" : deptName.Trim();

                // 4. Calculate totals
                var totItem = (short)request.Items.Count;
                var totQty = request.Items.Sum(x => x.Qty);
                var totAmt = request.Items.Sum(x => x.TotalValue);

                // 5. Update Indent_Master header
                const string updateHeaderSql = @"
                    UPDATE Indent_Master SET 
                        Ind_Date = @IndDate, 
                        Dept_code = @DeptCode, 
                        Store_Code = @StoreCode, 
                        Priority = @Priority, 
                        Source = @Source, 
                        Tot_Item = @TotItem, 
                        Tot_qty = @TotQty, 
                        Tot_Amt = @TotAmt, 
                        Remark = @Remark, 
                        Ind_EDate = GETDATE(), 
                        Ind_UsrName = @Username, 
                        Ind_EMode = 'Edit', 
                        Ind_CapMode = @CapMode 
                    WHERE Ind_Code = @IndCode;";

                await conn.ExecuteAsync(updateHeaderSql, new
                {
                    IndCode = indCode.Trim(),
                    IndDate = request.IndDate,
                    DeptCode = request.DeptCode,
                    StoreCode = request.StoreCode,
                    Priority = string.IsNullOrWhiteSpace(request.Priority) ? "Normal" : request.Priority.Trim(),
                    Source = string.IsNullOrWhiteSpace(request.Source) ? "Manual" : request.Source.Trim(),
                    TotItem = totItem,
                    TotQty = totQty,
                    TotAmt = totAmt,
                    Remark = request.Remark?.Trim() ?? string.Empty,
                    Username = username.Trim(),
                    CapMode = request.CapMode
                }, tx);

                // 6. Delete old line items
                const string deleteLinesSql = "DELETE FROM indent_det WHERE Ind_Code = @IndCode;";
                await conn.ExecuteAsync(deleteLinesSql, new { IndCode = indCode.Trim() }, tx);

                // 7. Insert updated line items
                const string insertLineSql = @"
                    INSERT INTO indent_det (
                        Ind_Code, reqNo, Srno, Code, Description, uom, qty, Rate, 
                        totalValue, KH_Code, Dept_code, ReqDate, inq, isEnq
                    ) VALUES (
                        @IndCode, @ReqNo, @Srno, @Code, @Description, @Uom, @Qty, @Rate, 
                        @TotalValue, @KhCode, @DeptCode, @ReqDate, 0, 0
                    );";

                for (var i = 0; i < request.Items.Count; i++)
                {
                    var item = request.Items[i];
                    var reqNo = string.IsNullOrWhiteSpace(item.ReqNo) ? "None" : item.ReqNo.Trim();
                    var lineDept = item.DeptCode > 0 ? item.DeptCode : request.DeptCode;
                    var reqDate = item.ReqDate != default ? item.ReqDate : request.IndDate;

                    await conn.ExecuteAsync(insertLineSql, new
                    {
                        IndCode = indCode.Trim(),
                        ReqNo = reqNo,
                        Srno = i,
                        Code = item.Code.Trim(),
                        Description = item.Description?.Trim() ?? string.Empty,
                        Uom = item.Uom,
                        Qty = item.Qty,
                        Rate = item.Rate,
                        TotalValue = item.TotalValue,
                        KhCode = item.KhCode,
                        DeptCode = lineDept,
                        ReqDate = reqDate
                    }, tx);

                    if (!string.IsNullOrWhiteSpace(reqNo) && !reqNo.Equals("None", StringComparison.OrdinalIgnoreCase))
                    {
                        const string updateReqSql = @"
                            UPDATE Requisition_Master 
                            SET IsInd = 'Indent', IndDate = @IndDate 
                            WHERE Req_Code = @ReqNo;";
                        await conn.ExecuteAsync(updateReqSql, new { IndDate = request.IndDate, ReqNo = reqNo }, tx);
                    }
                }

                // 8. DAYBOOK audit log
                const string insertDaybookSql = @"
                    INSERT INTO DAYBOOK (
                        DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME
                    ) VALUES (
                        GETDATE(), @Username, @DeptName, @TotQty, @IndCode, 'EDIT', 'IDT', 1, @CompanyName
                    );";

                await conn.ExecuteAsync(insertDaybookSql, new
                {
                    Username = username.Trim(),
                    DeptName = deptName,
                    TotQty = totQty,
                    IndCode = indCode.Trim(),
                    CompanyName = companyName
                }, tx);

                tx.Commit();
                _logger.LogInformation("Successfully updated Indent {IndCode} by user {User}", indCode, username);
                return indCode.Trim();
            }
            catch (Exception ex)
            {
                tx.Rollback();
                _logger.LogError(ex, "Transaction rolled back during Indent update for {IndCode} by user {User}", indCode, username);
                throw;
            }
        }

        public async Task<bool> DeleteIndentAsync(string indCode, string username)
        {
            if (string.IsNullOrWhiteSpace(indCode)) throw new ArgumentException("Indent code is required.", nameof(indCode));

            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);

            using var conn = CreateConnection();
            if (conn.State != ConnectionState.Open) conn.Open();
            using var tx = conn.BeginTransaction(IsolationLevel.Serializable);

            try
            {
                // 1. Fetch header to check date and lock
                const string fetchHeaderSql = "SELECT Ind_Date, Tot_qty, Dept_code FROM Indent_Master WHERE Ind_Code = @IndCode;";
                var header = await conn.QueryFirstOrDefaultAsync<dynamic>(fetchHeaderSql, new { IndCode = indCode.Trim() }, tx);
                if (header == null) return false;

                DateTime indDate = header.Ind_Date;
                double totQty = (double)header.Tot_qty;
                int deptCode = (int)header.Dept_code;

                const string lockCheckSql = @"
                    SELECT COUNT(1) 
                    FROM LOCKDATAMST 
                    WHERE CAST(@IndDate AS DATE) = CAST(LDM_STDT AS DATE);";

                var isLocked = (await conn.ExecuteScalarAsync<int>(lockCheckSql, new { IndDate = indDate.Date }, tx)) > 0;
                if (isLocked)
                {
                    throw new InvalidOperationException($"The transaction date '{indDate:yyyy-MM-dd}' is locked. Cannot delete Indent.");
                }

                // 2. Resolve Department Name
                const string deptNameSql = "SELECT TOP 1 LAB_NAME FROM LABOURMST WHERE LAB_CODE = @DeptCode;";
                var deptName = await conn.ExecuteScalarAsync<string>(deptNameSql, new { DeptCode = deptCode }, tx);
                deptName = string.IsNullOrWhiteSpace(deptName) ? "REGULAR" : deptName.Trim();

                // 3. Reset any linked Requisition_Master records
                const string getReqSql = "SELECT DISTINCT reqNo FROM indent_det WHERE Ind_Code = @IndCode AND reqNo <> 'None' AND reqNo IS NOT NULL;";
                var linkedReqs = (await conn.QueryAsync<string>(getReqSql, new { IndCode = indCode.Trim() }, tx)).ToList();
                foreach (var reqNo in linkedReqs)
                {
                    const string resetReqSql = "UPDATE Requisition_Master SET IsInd = '0', IndDate = NULL WHERE Req_Code = @ReqNo;";
                    await conn.ExecuteAsync(resetReqSql, new { ReqNo = reqNo }, tx);
                }

                // 4. Delete line items
                const string deleteLinesSql = "DELETE FROM indent_det WHERE Ind_Code = @IndCode;";
                await conn.ExecuteAsync(deleteLinesSql, new { IndCode = indCode.Trim() }, tx);

                // 5. Delete header
                const string deleteHeaderSql = "DELETE FROM Indent_Master WHERE Ind_Code = @IndCode;";
                await conn.ExecuteAsync(deleteHeaderSql, new { IndCode = indCode.Trim() }, tx);

                // 6. DAYBOOK audit log
                const string insertDaybookSql = @"
                    INSERT INTO DAYBOOK (
                        DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME
                    ) VALUES (
                        GETDATE(), @Username, @DeptName, @TotQty, @IndCode, 'DELETE', 'IDT', 1, @CompanyName
                    );";

                await conn.ExecuteAsync(insertDaybookSql, new
                {
                    Username = username.Trim(),
                    DeptName = deptName,
                    TotQty = totQty,
                    IndCode = indCode.Trim(),
                    CompanyName = companyName
                }, tx);

                tx.Commit();
                _logger.LogInformation("Successfully deleted Indent {IndCode} by user {User}", indCode, username);
                return true;
            }
            catch (Exception ex)
            {
                tx.Rollback();
                _logger.LogError(ex, "Transaction rolled back during Indent deletion of {IndCode} by user {User}", indCode, username);
                throw;
            }
        }
    }
}
