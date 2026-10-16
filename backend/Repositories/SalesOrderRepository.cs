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
    public class SalesOrderRepository : ISalesOrderRepository
    {
        private readonly string _connectionString;
        private readonly IConfiguration _configuration;
        private readonly ILogger<SalesOrderRepository> _logger;

        public SalesOrderRepository(
            IConfiguration configuration,
            ILogger<SalesOrderRepository> logger)
        {
            _configuration = configuration;
            _logger = logger;
            _connectionString = DbConnectionHelper.ResolveConnectionString(configuration);
        }

        private IDbConnection CreateConnection() => new SqlConnection(_connectionString);

        public async Task<SalesOrderPagedResult<SalesOrderHeaderDto>> GetSalesOrdersAsync(SalesOrderFilterRequest filter)
        {
            var sb = new StringBuilder(@"
                FROM Sal_Ord_Mst som
                LEFT JOIN partymst pm ON som.P_Code = pm.P_Code
                LEFT JOIN SALESPERSONMST spm ON som.SP_CD = spm.SPM_CODE
                LEFT JOIN KHATAMST km ON som.Cost_Cd = km.KH_CODE
                WHERE 1=1 ");

            var p = new DynamicParameters();

            if (filter.FromDate.HasValue)
            {
                sb.Append(" AND CAST(som.SO_Date AS DATE) >= CAST(@FromDate AS DATE) ");
                p.Add("FromDate", filter.FromDate.Value.Date);
            }
            if (filter.ToDate.HasValue)
            {
                sb.Append(" AND CAST(som.SO_Date AS DATE) <= CAST(@ToDate AS DATE) ");
                p.Add("ToDate", filter.ToDate.Value.Date);
            }
            if (filter.CostCd.HasValue && filter.CostCd.Value > 0)
            {
                sb.Append(" AND som.Cost_Cd = @CostCd ");
                p.Add("CostCd", filter.CostCd.Value);
            }
            if (filter.PCode.HasValue && filter.PCode.Value > 0)
            {
                sb.Append(" AND som.P_Code = @PCode ");
                p.Add("PCode", filter.PCode.Value);
            }
            if (filter.SpCd.HasValue && filter.SpCd.Value > 0)
            {
                sb.Append(" AND som.SP_CD = @SpCd ");
                p.Add("SpCd", filter.SpCd.Value);
            }
            if (!string.IsNullOrWhiteSpace(filter.SearchQuery))
            {
                sb.Append(@" AND (
                    som.SO_No LIKE '%' + @Search + '%' 
                    OR pm.P_Name LIKE '%' + @Search + '%' 
                    OR spm.SPM_NAME LIKE '%' + @Search + '%' 
                    OR km.KH_NAME LIKE '%' + @Search + '%' 
                    OR pm.P_GST_IN LIKE '%' + @Search + '%'
                ) ");
                p.Add("Search", filter.SearchQuery.Trim());
            }

            var countSql = $"SELECT COUNT(1) {sb}";

            var dataSql = $@"
                SELECT 
                    som.SO_No AS SoNo, som.SO_Date AS SoDate, som.P_Code AS PCode, 
                    ISNULL(pm.P_Name, '') AS PartyName, ISNULL(pm.P_MOBILE, '') AS Mobile,
                    ISNULL(pm.P_GST_IN, '') AS Gstin, ISNULL(pm.P_GST_STATE, '') AS StateCode, 
                    ISNULL(pm.P_GST_REGADD, '') AS Address,
                    ISNULL(som.Dept_Code, 0) AS DeptCode,
                    ISNULL(som.SO_Mode, 'Direct') AS SoMode, 
                    ISNULL(som.Tot_Itm, 0) AS TotItm,
                    ISNULL(som.Tot_Qty, 0) AS TotQty, 
                    ISNULL(som.Tot_Disc, 0) AS TotDisc,
                    ISNULL(som.Tot_Amt, 0) AS TotAmt, 
                    ISNULL(som.Adv, 0) AS Adv,
                    ISNULL(som.PF_Chg, 0) AS PfChg,
                    ISNULL(som.Freight, 0) AS Freight,
                    ISNULL(som.Others, 0) AS Others,
                    ISNULL(som.NetAmt, 0) AS NetAmt,
                    CAST(ISNULL(som.Approved, 0) AS BIT) AS Approved, 
                    som.AppDate AS AppDate,
                    CAST(ISNULL(som.IsRec, 0) AS BIT) AS IsRec, 
                    som.RecDate AS RecDate,
                    CAST(ISNULL(som.CloseSO, 0) AS BIT) AS CloseSo, 
                    ISNULL(som.Supp_Ref, '') AS SuppRef,
                    ISNULL(som.Curr, 'INR') AS Curr, 
                    ISNULL(som.SOM_USRNAME, '') AS SomUsrName,
                    som.SOM_EDATE AS SomEDate, 
                    ISNULL(som.Remark, '') AS Remark, 
                    CAST(ISNULL(som.IsImp, 0) AS BIT) AS IsImp,
                    ISNULL(som.SO_CrDays, 0) AS SoCrDays, 
                    ISNULL(som.SOM_DELDAYS, 6) AS SomDelDays,
                    ISNULL(som.SOM_CAPMODE, 0) AS SomCapMode, 
                    ISNULL(som.COST_CD, 0) AS CostCd,
                    ISNULL(km.KH_NAME, '') AS CostCenterName,
                    ISNULL(som.SP_CD, 0) AS SpCd,
                    ISNULL(spm.SPM_NAME, '') AS SalesPersonName,
                    CAST(ISNULL(som.SOM_ISFREIGHT, 0) AS BIT) AS SomIsFreight
                {sb}
                ORDER BY som.SO_Date DESC, som.SO_No DESC
                OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;";

            var page = Math.Max(1, filter.Page);
            var pageSize = Math.Clamp(filter.PageSize, 1, 200);
            p.Add("Offset", (page - 1) * pageSize);
            p.Add("PageSize", pageSize);

            using var conn = CreateConnection();
            var totalCount = await conn.ExecuteScalarAsync<int>(countSql, p);
            var items = (await conn.QueryAsync<SalesOrderHeaderDto>(dataSql, p)).ToList();

            return new SalesOrderPagedResult<SalesOrderHeaderDto>
            {
                Items = items,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            };
        }

        public async Task<SalesOrderHeaderDto?> GetSalesOrderByNoAsync(string soNo)
        {
            if (string.IsNullOrWhiteSpace(soNo)) return null;
            soNo = Uri.UnescapeDataString(soNo).Trim();

            const string headerSql = @"
                SELECT 
                    som.SO_No AS SoNo, som.SO_Date AS SoDate, som.P_Code AS PCode, 
                    ISNULL(pm.P_Name, '') AS PartyName, ISNULL(pm.P_MOBILE, '') AS Mobile,
                    ISNULL(pm.P_GST_IN, '') AS Gstin, ISNULL(pm.P_GST_STATE, '') AS StateCode, 
                    ISNULL(pm.P_GST_REGADD, '') AS Address,
                    ISNULL(som.Dept_Code, 0) AS DeptCode,
                    ISNULL(som.SO_Mode, 'Direct') AS SoMode, 
                    ISNULL(som.Tot_Itm, 0) AS TotItm,
                    ISNULL(som.Tot_Qty, 0) AS TotQty, 
                    ISNULL(som.Tot_Disc, 0) AS TotDisc,
                    ISNULL(som.Tot_Amt, 0) AS TotAmt, 
                    ISNULL(som.Adv, 0) AS Adv,
                    ISNULL(som.PF_Chg, 0) AS PfChg,
                    ISNULL(som.Freight, 0) AS Freight,
                    ISNULL(som.Others, 0) AS Others,
                    ISNULL(som.NetAmt, 0) AS NetAmt,
                    CAST(ISNULL(som.Approved, 0) AS BIT) AS Approved, 
                    som.AppDate AS AppDate,
                    CAST(ISNULL(som.IsRec, 0) AS BIT) AS IsRec, 
                    som.RecDate AS RecDate,
                    CAST(ISNULL(som.CloseSO, 0) AS BIT) AS CloseSo, 
                    ISNULL(som.Supp_Ref, '') AS SuppRef,
                    ISNULL(som.Curr, 'INR') AS Curr, 
                    ISNULL(som.SOM_USRNAME, '') AS SomUsrName,
                    som.SOM_EDATE AS SomEDate, 
                    ISNULL(som.Remark, '') AS Remark, 
                    CAST(ISNULL(som.IsImp, 0) AS BIT) AS IsImp,
                    ISNULL(som.SO_CrDays, 0) AS SoCrDays, 
                    ISNULL(som.SOM_DELDAYS, 6) AS SomDelDays,
                    ISNULL(som.SOM_CAPMODE, 0) AS SomCapMode,
                    ISNULL(loc.LOCATION, '') AS CapModeName,
                    ISNULL(som.COST_CD, 0) AS CostCd,
                    ISNULL(km.KH_NAME, '') AS CostCenterName,
                    ISNULL(som.SP_CD, 0) AS SpCd,
                    ISNULL(spm.SPM_NAME, '') AS SalesPersonName,
                    CAST(ISNULL(som.SOM_ISFREIGHT, 0) AS BIT) AS SomIsFreight
                FROM Sal_Ord_Mst som
                LEFT JOIN partymst pm ON som.P_Code = pm.P_Code
                LEFT JOIN SALESPERSONMST spm ON som.SP_CD = spm.SPM_CODE
                LEFT JOIN KHATAMST km ON som.Cost_Cd = km.KH_CODE
                LEFT JOIN LOCATIONMST loc ON som.SOM_CAPMODE = loc.LOC_CODE AND loc.MODE = 'CAPCONS'
                WHERE LTRIM(RTRIM(som.SO_No)) = @SoNo;";

            const string itemsSql = @"
                SELECT 
                    sod.S_Id AS SId, sod.SO_No AS SoNo, ISNULL(sod.SrNo, 1) AS SrNo,
                    ISNULL(sod.Ind_Code, 'None') AS IndCode, ISNULL(sod.Quo_Code, 'None') AS QuoCode,
                    sod.I_Code AS ICode, ISNULL(im.I_NAME1, '') AS ItemName,
                    ISNULL(sod.UOM, 0) AS Uom, ISNULL(um.UNIT_NAME, '') AS UnitName,
                    ISNULL(sod.Qty, 0) AS Qty, ISNULL(sod.AccQty, 0) AS AccQty,
                    ISNULL(sod.Rate, 0) AS Rate, ISNULL(sod.Disc, 0) AS Disc,
                    ISNULL(sod.Amount, 0) AS Amount, 
                    CAST(ISNULL(sod.IsAppro, 0) AS BIT) AS IsAppro,
                    CAST(ISNULL(sod.IsRec, 0) AS BIT) AS IsRec,
                    CAST(ISNULL(sod.IsReject, 0) AS BIT) AS IsReject,
                    CAST(ISNULL(sod.IsHold, 0) AS BIT) AS IsHold,
                    ISNULL(sod.Kh_Code, 0) AS KhCode, ISNULL(km.KH_NAME, '') AS DivisionName,
                    ISNULL(sod.DEP_CODE, 0) AS DepCode, ISNULL(lm.LAB_NAME, '') AS DeptName,
                    ISNULL(sod.mrgno, '') AS MrgNo,
                    ISNULL(CAST(sod.SPECIFICATION AS NVARCHAR(MAX)), '') AS Specification,
                    CAST(ISNULL(sod.closeSO, 0) AS BIT) AS CloseSo
                FROM Sal_Ordr_Det sod
                LEFT JOIN ITEMMST im ON sod.I_Code = im.I_Code
                LEFT JOIN UNITMST um ON sod.UOM = um.UNIT_CODE
                LEFT JOIN KHATAMST km ON sod.Kh_Code = km.KH_CODE
                LEFT JOIN LABOURMST lm ON sod.DEP_CODE = lm.LAB_CODE
                WHERE LTRIM(RTRIM(sod.SO_No)) = @SoNo
                ORDER BY sod.SrNo;";

            const string chargesSql = @"
                SELECT cd.Id AS Id, cd.Chg_Id AS ChgId, ISNULL(cm.CHG_NAME, '') AS ChgName,
                       cd.Code AS Code, ISNULL(cd.per, 0) AS Per, ISNULL(cd.Amt, 0) AS Amt,
                       ISNULL(cd.Mode, 'QUOTATION') AS Mode,
                       CASE 
                           WHEN LTRIM(RTRIM(cm.ADDLESS)) = '-' OR LTRIM(RTRIM(cm.ADDLESS)) = '-1' THEN CAST(-1 AS SMALLINT) 
                           ELSE CAST(1 AS SMALLINT) 
                       END AS AddLess,
                       ISNULL(cm.EXP, '') AS Exp, ISNULL(cd.Remark, '') AS Remark
                FROM ChargesDet cd
                LEFT JOIN CHARGESMST cm ON cd.Chg_Id = cm.CHG_ID
                WHERE LTRIM(RTRIM(cd.Code)) = @SoNo AND cd.Mode IN ('QUOTATION', 'PURCHASE', 'SALES')
                ORDER BY cm.PRIORITY;";

            const string conditionsSql = @"
                SELECT ConId AS ConId, ISNULL(Con_No, 0) AS ConNo, Code AS Code, '' AS ConditionText
                FROM ConditionDet
                WHERE LTRIM(RTRIM(Code)) = @SoNo
                ORDER BY Con_No;";

            using var conn = CreateConnection();
            var header = await conn.QueryFirstOrDefaultAsync<SalesOrderHeaderDto>(headerSql, new { SoNo = soNo });
            if (header == null) return null;

            header.Items = (await conn.QueryAsync<SalesOrderItemDto>(itemsSql, new { SoNo = soNo })).ToList();
            header.Charges = (await conn.QueryAsync<SalesOrderChargeDto>(chargesSql, new { SoNo = soNo })).ToList();
            header.Conditions = (await conn.QueryAsync<SalesOrderConditionDto>(conditionsSql, new { SoNo = soNo })).ToList();

            return header;
        }

        public async Task<SalesOrderLookupsDto> GetLookupsAsync()
        {
            using var conn = CreateConnection();

            var locationContext = CompanyConfigHelper.ResolveLocationCode(_configuration);

            // 1. Next SO Number Calculation (FY based, Apr 1 to Mar 31)
            var now = DateTime.Today;
            var fyStart = now.Month >= 4 ? new DateTime(now.Year, 4, 1) : new DateTime(now.Year - 1, 4, 1);
            var fyEnd = fyStart.AddYears(1).AddDays(-1);
            var fyYearSuffix = (fyEnd.Year % 100).ToString("D2"); // e.g. 2027 -> "27"

            const string nextSeqSql = @"
                SELECT ISNULL(MAX(TRY_CAST(SUBSTRING(SO_NO, 6, 6) AS INT)), 0)
                FROM Sal_Ord_Mst
                WHERE SOM_LOC = @Loc 
                  AND LEFT(SO_NO, 4) = 'SALO' 
                  AND SO_Date >= @FyStart 
                  AND SO_Date <= @FyEnd;";

            var maxSeq = await conn.ExecuteScalarAsync<int>(nextSeqSql, new
            {
                Loc = locationContext,
                FyStart = fyStart,
                FyEnd = fyEnd
            });

            var nextSoNo = $"SALO/{(maxSeq + 1):D6}/{fyYearSuffix}";

            // 2. Currencies
            const string currenciesSql = @"
                SELECT DISTINCT CURR 
                FROM Sal_Ord_Mst 
                WHERE CURR IS NOT NULL AND LTRIM(RTRIM(CURR)) <> '' 
                ORDER BY CURR;";
            var currencies = (await conn.QueryAsync<string>(currenciesSql)).ToList();
            if (!currencies.Contains("INR", StringComparer.OrdinalIgnoreCase))
            {
                currencies.Insert(0, "INR");
            }

            // 3. CapCons Location Stores
            const string capModesSql = @"
                SELECT LOC_CODE AS LocCode, LOCATION AS Location 
                FROM LOCATIONMST 
                WHERE MODE = 'CAPCONS' 
                ORDER BY LOCATION;";
            var capModes = (await conn.QueryAsync<LocationLookupDto>(capModesSql)).ToList();

            // 4. Cost Centers / Divisions
            const string costCentersSql = @"
                SELECT KH_CODE AS KhCode, KH_NAME AS KhName 
                FROM KHATAMST 
                WHERE (KH_DISPLAY IS NULL OR KH_DISPLAY = 0) 
                ORDER BY KH_NAME;";
            var costCenters = (await conn.QueryAsync<CostCenterLookupDto>(costCentersSql)).ToList();

            // 5. Sales Persons
            const string salesPersonsSql = @"
                SELECT SPM_CODE AS SpmCode, SPM_NAME AS SpmName 
                FROM SALESPERSONMST 
                ORDER BY SPM_NAME;";
            var salesPersons = (await conn.QueryAsync<SalesPersonLookupDto>(salesPersonsSql)).ToList();

            // 6. Default Charges Master
            const string chargesSql = @"
                SELECT PRIORITY AS Priority, 0 AS Id, CHG_ID AS ChgId, CHG_NAME AS ChgName, 
                       '' AS Code, ISNULL(DISC, 0) AS Per, 0 AS Amt, 'QUOTATION' AS Mode,
                       CASE 
                           WHEN LTRIM(RTRIM(ADDLESS)) = '-' OR LTRIM(RTRIM(ADDLESS)) = '-1' THEN CAST(-1 AS SMALLINT) 
                           ELSE CAST(1 AS SMALLINT) 
                       END AS AddLess,
                       ISNULL(EXP, '') AS Exp, '' AS Remark
                FROM CHARGESMST
                WHERE LOC <> 0 AND CHG_PO <> 0
                ORDER BY PRIORITY;";
            var defaultCharges = (await conn.QueryAsync<SalesOrderChargeDto>(chargesSql)).ToList();

            return new SalesOrderLookupsDto
            {
                NextSoNo = nextSoNo,
                Currencies = currencies,
                CapModes = capModes,
                CostCenters = costCenters,
                SalesPersons = salesPersons,
                DefaultCharges = defaultCharges,
                CompanyStateCode = "24"
            };
        }

        public async Task<SalesOrderPagedResult<CustomerLookupDto>> GetCustomersLookupAsync(string search, int page, int pageSize)
        {
            const string countSql = @"
                SELECT COUNT(1)
                FROM PARTYMST AS A 
                LEFT JOIN GROUPMST AS B ON A.P_GRCODE = B.GR_CODE 
                WHERE (CHARINDEX('DEB', B.GR_NAME) > 0 OR A.P_GRCODE = 4) 
                  AND (A.P_GRCODE = 4 OR A.P_GST_STATE <> '') 
                  AND (A.P_VIEW IS NULL OR A.P_VIEW <> 'UNSEEN') 
                  AND (CHARINDEX('DEBT', B.GR_NAME) > 0 OR A.P_GRCODE = 4) 
                  AND B.GR_GPNP = 'BALANCE SHEET'
                  AND (@Search = '' OR A.P_NAME LIKE '%' + @Search + '%' OR A.P_GST_IN LIKE '%' + @Search + '%');";

            const string dataSql = @"
                SELECT A.P_CODE AS PCode, A.P_NAME AS PName, ISNULL(A.P_MOBILE, '') AS Mobile,
                       ISNULL(A.P_GST_IN, '') AS Gstin, ISNULL(A.P_GST_STATE, '') AS StateCode, 
                       ISNULL(A.P_GST_REGADD, '') AS Address, CAST(ISNULL(A.P_CrDay, 0) AS INT) AS CreditDays
                FROM PARTYMST AS A 
                LEFT JOIN GROUPMST AS B ON A.P_GRCODE = B.GR_CODE 
                WHERE (CHARINDEX('DEB', B.GR_NAME) > 0 OR A.P_GRCODE = 4) 
                  AND (A.P_GRCODE = 4 OR A.P_GST_STATE <> '') 
                  AND (A.P_VIEW IS NULL OR A.P_VIEW <> 'UNSEEN') 
                  AND (CHARINDEX('DEBT', B.GR_NAME) > 0 OR A.P_GRCODE = 4) 
                  AND B.GR_GPNP = 'BALANCE SHEET'
                  AND (@Search = '' OR A.P_NAME LIKE '%' + @Search + '%' OR A.P_GST_IN LIKE '%' + @Search + '%')
                ORDER BY A.P_NAME
                OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;";

            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 200);
            var offset = (page - 1) * pageSize;
            var cleanSearch = search?.Trim() ?? string.Empty;

            using var conn = CreateConnection();
            var totalCount = await conn.ExecuteScalarAsync<int>(countSql, new { Search = cleanSearch });
            var items = (await conn.QueryAsync<CustomerLookupDto>(dataSql, new { Search = cleanSearch, Offset = offset, PageSize = pageSize })).ToList();

            return new SalesOrderPagedResult<CustomerLookupDto>
            {
                Items = items,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            };
        }

        public async Task<SalesOrderPagedResult<SalesOrderItemLookupDto>> GetItemsLookupAsync(string search, int page, int pageSize)
        {
            const string countSql = @"
                SELECT COUNT(1)
                FROM ITEMMST AS IM 
                WHERE (IM.I_BLOCK IS NULL OR IM.I_BLOCK = 0) 
                  AND IM.I_HSN <> '' 
                  AND (@Search = '' OR IM.I_CODE LIKE '%' + @Search + '%' OR IM.I_NAME1 LIKE '%' + @Search + '%');";

            const string dataSql = @"
                SELECT IM.I_CODE AS ICode, IM.I_NAME1 AS ItName, 
                       ISNULL(UM.UNIT_CODE, 0) AS UnitCode, ISNULL(UM.UNIT_NAME, '') AS UnitName,
                       ISNULL(IM.I_HSN, '') AS Hsn
                FROM ITEMMST AS IM 
                LEFT JOIN UNITMST AS UM ON UM.UNIT_CODE = IM.I_UOM 
                WHERE (IM.I_BLOCK IS NULL OR IM.I_BLOCK = 0) 
                  AND IM.I_HSN <> '' 
                  AND (@Search = '' OR IM.I_CODE LIKE '%' + @Search + '%' OR IM.I_NAME1 LIKE '%' + @Search + '%')
                ORDER BY IM.I_NAME1
                OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;";

            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 200);
            var offset = (page - 1) * pageSize;
            var cleanSearch = search?.Trim() ?? string.Empty;

            using var conn = CreateConnection();
            var totalCount = await conn.ExecuteScalarAsync<int>(countSql, new { Search = cleanSearch });
            var items = (await conn.QueryAsync<SalesOrderItemLookupDto>(dataSql, new { Search = cleanSearch, Offset = offset, PageSize = pageSize })).ToList();

            return new SalesOrderPagedResult<SalesOrderItemLookupDto>
            {
                Items = items,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            };
        }

        public async Task<List<string>> GetRemarksLookupAsync(string query)
        {
            const string sql = @"
                SELECT TOP 20 REMARK 
                FROM Sal_Ord_Mst 
                WHERE REMARK IS NOT NULL 
                  AND LTRIM(RTRIM(REMARK)) <> '' 
                  AND (@Query = '' OR REMARK LIKE '%' + @Query + '%')
                GROUP BY REMARK 
                ORDER BY REMARK;";

            using var conn = CreateConnection();
            var remarks = (await conn.QueryAsync<string>(sql, new { Query = query?.Trim() ?? string.Empty })).ToList();
            return remarks;
        }

        public async Task<bool> IsDateLockedAsync(DateTime date)
        {
            const string sql = "SELECT COUNT(1) FROM LOCKDATAMST WHERE CAST(LDM_STDT AS DATE) = CAST(@Date AS DATE);";
            using var conn = CreateConnection();
            var count = await conn.ExecuteScalarAsync<int>(sql, new { Date = date.Date });
            return count > 0;
        }

        public async Task<string> SaveSalesOrderAsync(SalesOrderSaveRequest request, string username)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.PCode <= 0) throw new ArgumentException("Customer party is required.", nameof(request.PCode));
            if (request.Items == null || request.Items.Count == 0)
            {
                throw new ArgumentException("Sales Order must contain at least one line item.", nameof(request.Items));
            }
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Username is required for audit logging.", nameof(username));
            }

            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);
            var locationContext = CompanyConfigHelper.ResolveLocationCode(_configuration);

            using var conn = (SqlConnection)CreateConnection();
            await conn.OpenAsync();
            using var tx = conn.BeginTransaction();

            try
            {
                // 1. Verify Date Lock in LOCKDATAMST
                const string lockCheckSql = "SELECT COUNT(1) FROM LOCKDATAMST WHERE CAST(@SoDate AS DATE) = CAST(LDM_STDT AS DATE);";
                var lockCount = await conn.ExecuteScalarAsync<int>(lockCheckSql, new { SoDate = request.SoDate.Date }, tx);
                if (lockCount > 0)
                {
                    throw new InvalidOperationException($"The date {request.SoDate:yyyy-MM-dd} is locked in LOCKDATAMST. Transaction rejected.");
                }

                // 2. Fetch Customer name for audit
                const string partyNameSql = "SELECT P_NAME FROM PARTYMST WHERE P_CODE = @PCode;";
                var partyName = await conn.ExecuteScalarAsync<string>(partyNameSql, new { PCode = request.PCode }, tx) ?? "CUSTOMER";

                var isNew = string.IsNullOrWhiteSpace(request.SoNo);
                string soNo;

                if (isNew)
                {
                    // Compute new sequence atomically under UPDLOCK/HOLDLOCK
                    var now = request.SoDate.Date;
                    var fyStart = now.Month >= 4 ? new DateTime(now.Year, 4, 1) : new DateTime(now.Year - 1, 4, 1);
                    var fyEnd = fyStart.AddYears(1).AddDays(-1);
                    var fyYearSuffix = (fyEnd.Year % 100).ToString("D2");

                    const string nextSeqLockedSql = @"
                        SELECT ISNULL(MAX(TRY_CAST(SUBSTRING(SO_NO, 6, 6) AS INT)), 0)
                        FROM Sal_Ord_Mst WITH (UPDLOCK, HOLDLOCK)
                        WHERE SOM_LOC = @Loc 
                          AND LEFT(SO_NO, 4) = 'SALO' 
                          AND SO_Date >= @FyStart 
                          AND SO_Date <= @FyEnd;";

                    var currentSeq = await conn.ExecuteScalarAsync<int>(nextSeqLockedSql, new
                    {
                        Loc = locationContext,
                        FyStart = fyStart,
                        FyEnd = fyEnd
                    }, tx);

                    soNo = $"SALO/{(currentSeq + 1):D6}/{fyYearSuffix}";
                }
                else
                {
                    soNo = Uri.UnescapeDataString(request.SoNo!).Trim();

                    // Ensure record exists & is not received
                    const string checkExistSql = @"
                        SELECT CAST(ISNULL(isrec, 0) AS BIT) AS IsRec 
                        FROM Sal_Ord_Mst 
                        WHERE LTRIM(RTRIM(SO_No)) = @SoNo;";
                    var existing = await conn.QueryFirstOrDefaultAsync<dynamic>(checkExistSql, new { SoNo = soNo }, tx);
                    if (existing == null)
                    {
                        throw new KeyNotFoundException($"Sales Order '{soNo}' was not found.");
                    }
                    if (Convert.ToInt32(existing.IsRec) != 0)
                    {
                        throw new InvalidOperationException($"Sales Order '{soNo}' has already been delivered/received and cannot be edited.");
                    }

                    // Delete existing child records
                    await conn.ExecuteAsync("DELETE FROM ChargesDet WHERE LTRIM(RTRIM(Code)) = @SoNo AND Mode IN ('QUOTATION', 'PURCHASE', 'SALES');", new { SoNo = soNo }, tx);
                    await conn.ExecuteAsync("DELETE FROM ConditionDet WHERE LTRIM(RTRIM(Code)) = @SoNo;", new { SoNo = soNo }, tx);
                    await conn.ExecuteAsync("DELETE FROM Sal_Ordr_Det WHERE LTRIM(RTRIM(SO_No)) = @SoNo;", new { SoNo = soNo }, tx);
                }

                // 3. DAYBOOK Audit Trail
                const string daybookSql = @"
                    INSERT INTO DAYBOOK(DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES(GETDATE(), @DbUser, @PName, @Amt, @RefNo, @Action, 'P.O', 1, @CompanyName);";

                var action = isNew ? "NEW" : "EDIT";

                // Audit row 1: Customer header summary
                await conn.ExecuteAsync(daybookSql, new
                {
                    DbUser = username.Trim(),
                    PName = partyName,
                    Amt = request.NetAmt,
                    RefNo = soNo,
                    Action = action,
                    CompanyName = companyName
                }, tx);

                // Audit rows 2..N: Line item descriptions & Quantities
                foreach (var item in request.Items)
                {
                    var itemName = await conn.ExecuteScalarAsync<string>(
                        "SELECT I_NAME1 FROM ITEMMST WHERE I_CODE = @ICode;", new { ICode = item.ICode }, tx) ?? item.ICode;

                    await conn.ExecuteAsync(daybookSql, new
                    {
                        DbUser = username.Trim(),
                        PName = itemName,
                        Amt = item.Qty,
                        RefNo = soNo,
                        Action = action,
                        CompanyName = companyName
                    }, tx);
                }

                // 4. Header Insert / Update in Sal_Ord_Mst
                if (isNew)
                {
                    const string insertHeaderSql = @"
                        INSERT INTO Sal_Ord_Mst (
                            SO_NO, SO_Date, P_Code, Dept_Code, SO_Mode, Tot_Itm, Tot_Qty, Tot_Disc,
                            Tot_Amt, Adv, PF_Chg, Excise, Freight, Others, NetAmt, Remark,
                            Approved, AppDate, IsRec, RecDate, IsImp, Curr, CloseSO, Supp_Ref,
                            SO_CrDays, SOM_LOC, SOM_EDATE, SOM_USRNAME, SOM_EMODE, SOM_DELDAYS,
                            SOM_CAPMODE, TYPEID, SOM_ISFREIGHT, COST_CD, SP_CD, SOM_AddCD
                        ) VALUES (
                            @SoNo, @SoDate, @PCode, @DeptCode, @SoMode, @TotItm, @TotQty, @TotDisc,
                            @TotAmt, 0, @PfChg, 0, @Freight, @Others, @NetAmt, @Remark,
                            0, NULL, 0, NULL, @IsImp, @Curr, 0, @SuppRef,
                            @SoCrDays, @SomLoc, GETDATE(), @UsrName, 'New', @SomDelDays,
                            @SomCapMode, 0, @SomIsFreight, @CostCd, @SpCd, 0
                        );";

                    await conn.ExecuteAsync(insertHeaderSql, new
                    {
                        SoNo = soNo,
                        SoDate = request.SoDate.Date,
                        request.PCode,
                        DeptCode = request.DeptCode > 0 ? request.DeptCode : 0,
                        SoMode = string.IsNullOrWhiteSpace(request.SoMode) ? "Direct" : request.SoMode,
                        TotItm = (short)request.Items.Count,
                        request.TotQty,
                        request.TotDisc,
                        request.TotAmt,
                        request.PfChg,
                        request.Freight,
                        request.Others,
                        request.NetAmt,
                        Remark = request.Remark ?? string.Empty,
                        IsImp = request.IsImp ? 1 : 0,
                        Curr = string.IsNullOrWhiteSpace(request.Curr) ? "INR" : request.Curr,
                        SuppRef = request.SuppRef ?? string.Empty,
                        request.SoCrDays,
                        SomLoc = locationContext,
                        UsrName = username.Trim(),
                        request.SomDelDays,
                        request.SomCapMode,
                        SomIsFreight = request.SomIsFreight ? 1 : 0,
                        CostCd = request.CostCd > 0 ? request.CostCd : 1,
                        SpCd = request.SpCd > 0 ? request.SpCd : -1
                    }, tx);
                }
                else
                {
                    const string updateHeaderSql = @"
                        UPDATE Sal_Ord_Mst SET
                            SO_Date = @SoDate,
                            P_Code = @PCode,
                            Dept_Code = @DeptCode,
                            SO_Mode = @SoMode,
                            Tot_Itm = @TotItm,
                            Tot_Qty = @TotQty,
                            Tot_Disc = @TotDisc,
                            Tot_Amt = @TotAmt,
                            PF_Chg = @PfChg,
                            Freight = @Freight,
                            Others = @Others,
                            NetAmt = @NetAmt,
                            Remark = @Remark,
                            IsImp = @IsImp,
                            Curr = @Curr,
                            Supp_Ref = @SuppRef,
                            SO_CrDays = @SoCrDays,
                            SOM_LOC = @SomLoc,
                            SOM_EDATE = GETDATE(),
                            SOM_USRNAME = @UsrName,
                            SOM_EMODE = 'Edit',
                            SOM_DELDAYS = @SomDelDays,
                            SOM_CAPMODE = @SomCapMode,
                            SOM_ISFREIGHT = @SomIsFreight,
                            COST_CD = @CostCd,
                            SP_CD = @SpCd
                        WHERE LTRIM(RTRIM(SO_No)) = @SoNo;";

                    await conn.ExecuteAsync(updateHeaderSql, new
                    {
                        SoNo = soNo,
                        SoDate = request.SoDate.Date,
                        request.PCode,
                        DeptCode = request.DeptCode > 0 ? request.DeptCode : 0,
                        SoMode = string.IsNullOrWhiteSpace(request.SoMode) ? "Direct" : request.SoMode,
                        TotItm = (short)request.Items.Count,
                        request.TotQty,
                        request.TotDisc,
                        request.TotAmt,
                        request.PfChg,
                        request.Freight,
                        request.Others,
                        request.NetAmt,
                        Remark = request.Remark ?? string.Empty,
                        IsImp = request.IsImp ? 1 : 0,
                        Curr = string.IsNullOrWhiteSpace(request.Curr) ? "INR" : request.Curr,
                        SuppRef = request.SuppRef ?? string.Empty,
                        request.SoCrDays,
                        SomLoc = locationContext,
                        UsrName = username.Trim(),
                        request.SomDelDays,
                        request.SomCapMode,
                        SomIsFreight = request.SomIsFreight ? 1 : 0,
                        CostCd = request.CostCd > 0 ? request.CostCd : 1,
                        SpCd = request.SpCd > 0 ? request.SpCd : -1
                    }, tx);
                }

                // 5. Insert Line Items into Sal_Ordr_Det
                const string insertDetSql = @"
                    INSERT INTO Sal_Ordr_Det (
                        SO_No, SrNo, Ind_Code, Quo_Code, I_Code, UOM, Qty, Rate, Disc,
                        Amount, Kh_Code, ExRate, ExAmt, Dep_Code, CloseSO, IsAppro, IsRec,
                        IsReject, IsHold, Specification
                    ) VALUES (
                        @SoNo, @SrNo, 'None', 'None', @ICode, @Uom, @Qty, @Rate, @Disc,
                        @Amount, @KhCode, 0, 0, @DepCode, 0, 0, 0,
                        0, 0, @Specification
                    );";

                int sr = 1;
                foreach (var it in request.Items)
                {
                    await conn.ExecuteAsync(insertDetSql, new
                    {
                        SoNo = soNo,
                        SrNo = sr++,
                        ICode = string.IsNullOrWhiteSpace(it.ICode) ? "ITEM" : it.ICode,
                        Uom = it.Uom > 0 ? it.Uom : 1,
                        it.Qty,
                        it.Rate,
                        it.Disc,
                        it.Amount,
                        KhCode = it.KhCode > 0 ? it.KhCode : (request.CostCd > 0 ? request.CostCd : 1),
                        DepCode = it.DepCode > 0 ? it.DepCode : 0,
                        Specification = it.Specification ?? string.Empty
                    }, tx);
                }

                // 6. Insert Charges into ChargesDet
                const string maxChargeIdSql = "SELECT ISNULL(MAX(Id), 0) FROM ChargesDet WITH (UPDLOCK, HOLDLOCK);";
                var curChargeId = await conn.ExecuteScalarAsync<int>(maxChargeIdSql, transaction: tx);
                const string insertChargeSql = @"
                    INSERT INTO ChargesDet (Id, Chg_Id, Code, Per, Amt, Mode, IIND, Remark)
                    VALUES (@Id, @ChgId, @Code, @Per, @Amt, 'QUOTATION', -1, @Remark);";

                foreach (var chg in request.Charges)
                {
                    curChargeId++;
                    await conn.ExecuteAsync(insertChargeSql, new
                    {
                        Id = curChargeId,
                        chg.ChgId,
                        Code = soNo,
                        chg.Per,
                        chg.Amt,
                        Remark = chg.Remark ?? string.Empty
                    }, tx);
                }

                // 7. Insert Conditions into ConditionDet
                const string maxCondIdSql = "SELECT ISNULL(MAX(ConId), 0) FROM ConditionDet WITH (UPDLOCK, HOLDLOCK);";
                var curCondId = await conn.ExecuteScalarAsync<int>(maxCondIdSql, transaction: tx);
                const string insertCondSql = @"
                    INSERT INTO ConditionDet (ConId, Con_No, Code)
                    VALUES (@ConId, @ConNo, @Code);";

                foreach (var cond in request.Conditions)
                {
                    curCondId++;
                    await conn.ExecuteAsync(insertCondSql, new
                    {
                        ConId = curCondId,
                        cond.ConNo,
                        Code = soNo
                    }, tx);
                }

                tx.Commit();
                return soNo;
            }
            catch
            {
                tx.Rollback();
                throw;
            }
        }

        public async Task<bool> DeleteSalesOrderAsync(string soNo, string username)
        {
            if (string.IsNullOrWhiteSpace(soNo)) return false;
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Username is required for audit logging.", nameof(username));
            }

            soNo = Uri.UnescapeDataString(soNo).Trim();

            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);

            using var conn = (SqlConnection)CreateConnection();
            await conn.OpenAsync();
            using var tx = conn.BeginTransaction();

            try
            {
                // 1. Verify existence & eligibility
                const string checkSql = @"
                    SELECT som.SO_Date, som.NetAmt, ISNULL(pm.P_Name, 'CUSTOMER') AS PartyName,
                           CAST(ISNULL(som.IsRec, 0) AS BIT) AS IsRec
                    FROM Sal_Ord_Mst som
                    LEFT JOIN partymst pm ON som.P_Code = pm.P_Code
                    WHERE LTRIM(RTRIM(som.SO_No)) = @SoNo;";

                var so = await conn.QueryFirstOrDefaultAsync<dynamic>(checkSql, new { SoNo = soNo }, tx);
                if (so == null)
                {
                    throw new KeyNotFoundException($"Sales Order '{soNo}' was not found.");
                }

                int recVal = 0;
                try { recVal = Convert.ToInt32(so.IsRec); } catch { }

                if (recVal != 0)
                {
                    throw new InvalidOperationException($"Sales Order '{soNo}' has already been delivered/dispatched and cannot be deleted.");
                }

                DateTime soDate = (DateTime)so.SO_Date;
                const string lockCheckSql = "SELECT COUNT(1) FROM LOCKDATAMST WHERE CAST(@SoDate AS DATE) = CAST(LDM_STDT AS DATE);";
                var lockCount = await conn.ExecuteScalarAsync<int>(lockCheckSql, new { SoDate = soDate.Date }, tx);
                if (lockCount > 0)
                {
                    throw new InvalidOperationException($"The date {soDate:yyyy-MM-dd} is locked in LOCKDATAMST. Deletion rejected.");
                }

                // 2. DAYBOOK audit logging
                const string daybookSql = @"
                    INSERT INTO DAYBOOK(DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES(GETDATE(), @DbUser, @PName, @Amt, @RefNo, 'DELETE', 'P.O', 1, @CompanyName);";

                await conn.ExecuteAsync(daybookSql, new
                {
                    DbUser = username.Trim(),
                    PName = (string)so.PartyName,
                    Amt = (double)so.NetAmt,
                    RefNo = soNo,
                    CompanyName = companyName
                }, tx);

                // 3. Delete records
                await conn.ExecuteAsync("DELETE FROM ChargesDet WHERE LTRIM(RTRIM(Code)) = @SoNo AND Mode IN ('QUOTATION', 'PURCHASE', 'SALES');", new { SoNo = soNo }, tx);
                await conn.ExecuteAsync("DELETE FROM ConditionDet WHERE LTRIM(RTRIM(Code)) = @SoNo;", new { SoNo = soNo }, tx);
                await conn.ExecuteAsync("DELETE FROM Sal_Ordr_Det WHERE LTRIM(RTRIM(SO_No)) = @SoNo;", new { SoNo = soNo }, tx);
                var rows = await conn.ExecuteAsync("DELETE FROM Sal_Ord_Mst WHERE LTRIM(RTRIM(SO_No)) = @SoNo;", new { SoNo = soNo }, tx);

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
