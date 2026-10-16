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
    public class PurchaseOrderRepository : IPurchaseOrderRepository
    {
        private readonly string _connectionString;
        private readonly IConfiguration _configuration;

        public PurchaseOrderRepository(IConfiguration configuration)
        {
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
            _connectionString = DbConnectionHelper.ResolveConnectionString(configuration);
        }

        private IDbConnection CreateConnection() => new SqlConnection(_connectionString);

        public async Task<PurchaseOrderPagedResult<PurchaseOrderHeaderDto>> GetPurchaseOrdersAsync(PurchaseOrderFilterRequest filter)
        {
            const string countSql = @"
                SELECT COUNT(1)
                FROM Pur_Ord_Mst pom
                LEFT JOIN partymst pm ON pom.P_Code = pm.P_Code
                WHERE (@FromDate IS NULL OR pom.PO_Date >= @FromDate)
                  AND (@ToDate IS NULL OR pom.PO_Date <= @ToDate)
                  AND (@StrCode IS NULL OR @StrCode = 0 OR pom.P_Str_Code = @StrCode)
                  AND (@PCode IS NULL OR @PCode = 0 OR pom.P_Code = @PCode)
                  AND (@Search IS NULL OR @Search = '' OR pom.Po_No LIKE '%' + @Search + '%' OR pm.P_Name LIKE '%' + @Search + '%');";

            const string dataSql = @"
                SELECT pom.Po_No AS PoNo, pom.PO_Date AS PoDate, pom.P_Code AS PCode, 
                       ISNULL(pm.P_Name, '') AS PartyName, ISNULL(pm.P_GST_IN, '') AS Gstin,
                       ISNULL(pm.P_GST_STATE, '') AS StateCode, ISNULL(pm.P_GST_REGADD, '') AS Address,
                       ISNULL(pom.PO_DelCD, pom.P_Code) AS PoDelCd, ISNULL(delPm.P_Name, pm.P_Name) AS DelPartyName,
                       ISNULL(pom.P_Str_Code, 0) AS PStrCode, ISNULL(sm.STR_NAME, '') AS StoreName,
                       ISNULL(pom.Dept_Code, 0) AS DeptCode, ISNULL(lm.LAB_NAME, '') AS DeptName,
                       ISNULL(pom.PO_Mode, 'Direct') AS PoMode, ISNULL(pom.Tot_Itm, 0) AS TotItm,
                       ISNULL(pom.Tot_Qty, 0) AS TotQty, ISNULL(pom.Tot_Disc, 0) AS TotDisc,
                       ISNULL(pom.Tot_Amt, 0) AS TotAmt, ISNULL(pom.NetAmt, 0) AS NetAmt,
                       CAST(ISNULL(pom.Approved, 0) AS BIT) AS Approved, pom.AppDate AS AppDate,
                       CAST(ISNULL(pom.IsRec, 0) AS BIT) AS IsRec, pom.RecDate AS RecDate,
                       CAST(ISNULL(pom.ClosePO, 0) AS BIT) AS ClosePO, ISNULL(pom.Supp_Ref, '') AS SuppRef,
                       ISNULL(pom.Curr, '') AS Curr, ISNULL(pom.POM_UsrName, '') AS PomUsrName,
                       pom.POM_EDate AS PomEDate, ISNULL(pom.Words, '') AS Words,
                       ISNULL(pom.DTerms, '') AS DTerms, ISNULL(pom.PTerms, '') AS PTerms,
                       ISNULL(pom.Disp_Ins, '') AS DispIns, ISNULL(pom.Sp_Note, '') AS SpNote,
                       ISNULL(pom.Remark, '') AS Remark, CAST(ISNULL(pom.IsImp, 0) AS BIT) AS IsImp,
                       ISNULL(pom.PO_CrDays, 0) AS PoCrDays, ISNULL(pom.POM_DELDays, 0) AS PomDelDays,
                       ISNULL(pom.POM_CapMode, 0) AS PomCapMode, ISNULL(pom.CGPER, 0) AS CgPer,
                       ISNULL(pom.CGAMT, 0) AS CgAmt, ISNULL(pom.SGPER, 0) AS SgPer,
                       ISNULL(pom.SGAMT, 0) AS SgAmt, ISNULL(pom.IGPER, 0) AS IgPer,
                       ISNULL(pom.IGAMT, 0) AS IgAmt, ISNULL(pom.POM_BrCode, 0) AS PomBrCode,
                       ISNULL(bm.BR_NAME, '') AS BrokerName, ISNULL(pom.POM_IsFreight, 0) AS PomIsFreight
                FROM Pur_Ord_Mst pom
                LEFT JOIN partymst pm ON pom.P_Code = pm.P_Code
                LEFT JOIN partymst delPm ON pom.PO_DelCD = delPm.P_Code
                LEFT JOIN STOREMST sm ON pom.P_Str_Code = sm.STR_CODE
                LEFT JOIN LABOURMST lm ON pom.Dept_Code = lm.LAB_CODE
                LEFT JOIN BROKERMST bm ON pom.POM_BrCode = bm.BR_CODE
                WHERE (@FromDate IS NULL OR pom.PO_Date >= @FromDate)
                  AND (@ToDate IS NULL OR pom.PO_Date <= @ToDate)
                  AND (@StrCode IS NULL OR @StrCode = 0 OR pom.P_Str_Code = @StrCode)
                  AND (@PCode IS NULL OR @PCode = 0 OR pom.P_Code = @PCode)
                  AND (@Search IS NULL OR @Search = '' OR pom.Po_No LIKE '%' + @Search + '%' OR pm.P_Name LIKE '%' + @Search + '%')
                ORDER BY pom.PO_Date DESC, pom.Po_No DESC
                OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;";

            var page = Math.Max(1, filter.Page);
            var pageSize = Math.Clamp(filter.PageSize, 1, 500);
            var offset = (page - 1) * pageSize;

            using var conn = CreateConnection();
            var totalCount = await conn.ExecuteScalarAsync<int>(countSql, new
            {
                filter.FromDate,
                filter.ToDate,
                filter.StrCode,
                filter.PCode,
                Search = filter.SearchQuery?.Trim()
            });

            var items = (await conn.QueryAsync<PurchaseOrderHeaderDto>(dataSql, new
            {
                filter.FromDate,
                filter.ToDate,
                filter.StrCode,
                filter.PCode,
                Search = filter.SearchQuery?.Trim(),
                Offset = offset,
                PageSize = pageSize
            })).ToList();

            return new PurchaseOrderPagedResult<PurchaseOrderHeaderDto>
            {
                Items = items,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            };
        }

        public async Task<PurchaseOrderHeaderDto?> GetPurchaseOrderByNoAsync(string poNo)
        {
            if (string.IsNullOrWhiteSpace(poNo)) return null;
            poNo = Uri.UnescapeDataString(poNo).Trim();

            const string headerSql = @"
                SELECT pom.Po_No AS PoNo, pom.PO_Date AS PoDate, pom.P_Code AS PCode, 
                       ISNULL(pm.P_Name, '') AS PartyName, ISNULL(pm.P_GST_IN, '') AS Gstin,
                       ISNULL(pm.P_GST_STATE, '') AS StateCode, ISNULL(pm.P_GST_REGADD, '') AS Address,
                       ISNULL(pom.PO_DelCD, pom.P_Code) AS PoDelCd, ISNULL(delPm.P_Name, pm.P_Name) AS DelPartyName,
                       ISNULL(pom.P_Str_Code, 0) AS PStrCode, ISNULL(sm.STR_NAME, '') AS StoreName,
                       ISNULL(pom.Dept_Code, 0) AS DeptCode, ISNULL(lm.LAB_NAME, '') AS DeptName,
                       ISNULL(pom.PO_Mode, 'Direct') AS PoMode, ISNULL(pom.Tot_Itm, 0) AS TotItm,
                       ISNULL(pom.Tot_Qty, 0) AS TotQty, ISNULL(pom.Tot_Disc, 0) AS TotDisc,
                       ISNULL(pom.Tot_Amt, 0) AS TotAmt, ISNULL(pom.NetAmt, 0) AS NetAmt,
                       CAST(ISNULL(pom.Approved, 0) AS BIT) AS Approved, pom.AppDate AS AppDate,
                       CAST(ISNULL(pom.IsRec, 0) AS BIT) AS IsRec, pom.RecDate AS RecDate,
                       CAST(ISNULL(pom.ClosePO, 0) AS BIT) AS ClosePO, ISNULL(pom.Supp_Ref, '') AS SuppRef,
                       ISNULL(pom.Curr, '') AS Curr, ISNULL(pom.POM_UsrName, '') AS PomUsrName,
                       pom.POM_EDate AS PomEDate, ISNULL(pom.Words, '') AS Words,
                       ISNULL(pom.DTerms, '') AS DTerms, ISNULL(pom.PTerms, '') AS PTerms,
                       ISNULL(pom.Disp_Ins, '') AS DispIns, ISNULL(pom.Sp_Note, '') AS SpNote,
                       ISNULL(pom.Remark, '') AS Remark, CAST(ISNULL(pom.IsImp, 0) AS BIT) AS IsImp,
                       ISNULL(pom.PO_CrDays, 0) AS PoCrDays, ISNULL(pom.POM_DELDays, 0) AS PomDelDays,
                       ISNULL(pom.POM_CapMode, 0) AS PomCapMode, ISNULL(pom.CGPER, 0) AS CgPer,
                       ISNULL(pom.CGAMT, 0) AS CgAmt, ISNULL(pom.SGPER, 0) AS SgPer,
                       ISNULL(pom.SGAMT, 0) AS SgAmt, ISNULL(pom.IGPER, 0) AS IgPer,
                       ISNULL(pom.IGAMT, 0) AS IgAmt, ISNULL(pom.POM_BrCode, 0) AS PomBrCode,
                       ISNULL(bm.BR_NAME, '') AS BrokerName, ISNULL(pom.POM_IsFreight, 0) AS PomIsFreight
                FROM Pur_Ord_Mst pom
                LEFT JOIN partymst pm ON pom.P_Code = pm.P_Code
                LEFT JOIN partymst delPm ON pom.PO_DelCD = delPm.P_Code
                LEFT JOIN STOREMST sm ON pom.P_Str_Code = sm.STR_CODE
                LEFT JOIN LABOURMST lm ON pom.Dept_Code = lm.LAB_CODE
                LEFT JOIN BROKERMST bm ON pom.POM_BrCode = bm.BR_CODE
                WHERE LTRIM(RTRIM(pom.Po_No)) = @PoNo;";

            const string itemsSql = @"
                SELECT pod.P_Id AS PId, pod.po_no AS PoNo, ISNULL(pod.SrNo, 1) AS SrNo,
                       ISNULL(pod.Ind_Code, 'None') AS IndCode, ISNULL(pod.Quo_Code, 'None') AS QuoCode,
                       pod.I_Code AS ICode, ISNULL(im.I_NAME1, '') AS ItemName, ISNULL(im.I_HSN, '') AS Hsn,
                       ISNULL(pod.UOM, 0) AS Uom, ISNULL(um.UNIT_NAME, '') AS UnitName,
                       ISNULL(pod.Qty, 0) AS Qty, ISNULL(pod.AccQty, 0) AS AccQty,
                       ISNULL(pod.Rate, 0) AS Rate, ISNULL(pod.Disc, 0) AS Disc,
                       ISNULL(pod.Amount, 0) AS Amount, ISNULL(pod.Kh_Code, 0) AS KhCode,
                       ISNULL(km.KH_NAME, '') AS DivisionName, ISNULL(pod.DEP_CODE, 0) AS DepCode,
                       ISNULL(lm.LAB_NAME, '') AS DeptName, ISNULL(pod.mrgno, '') AS MrgNo,
                       ISNULL(pod.SHADE, '') AS Shade, ISNULL(CAST(pod.SPECIFICATION AS NVARCHAR(MAX)), '') AS Specification,
                       ISNULL(pod.P_REMARK, '') AS PRemark, ISNULL(pod.Freight, 0) AS Freight,
                       ISNULL(pod.POD_IsFreight, 0) AS PodIsFreight, ISNULL(pod.CGPer, 0) AS CgPer,
                       ISNULL(pod.CGAmt, 0) AS CgAmt, ISNULL(pod.SGPer, 0) AS SgPer,
                       ISNULL(pod.SGAmt, 0) AS SgAmt, ISNULL(pod.IGPer, 0) AS IgPer,
                       ISNULL(pod.IGAmt, 0) AS IGAmt, (ISNULL(pod.Amount, 0) + ISNULL(pod.CGAmt, 0) + ISNULL(pod.SGAmt, 0) + ISNULL(pod.IGAmt, 0)) AS NetAmt,
                       ISNULL(pod.POD_STOCK, 0) AS PodStock, ISNULL(pod.POD_LASTRATE, 0) AS PodLastRate,
                       ISNULL(pod.POD_MakeID, 0) AS PodMakeId, ISNULL(makerLoc.LOCATION, '') AS MakerName,
                       ISNULL(pod.POD_ConvUOM, 0) AS PodConvUom, ISNULL(convU.UNIT_NAME, '') AS ConvUnitName,
                       ISNULL(pod.POD_ConvQty, 0) AS PodConvQty, CAST(ISNULL(pod.closePO, 0) AS BIT) AS ClosePO
                FROM Pur_Ordr_Det pod
                LEFT JOIN ITEMMST im ON pod.I_Code = im.I_Code
                LEFT JOIN UNITMST um ON pod.UOM = um.UNIT_CODE
                LEFT JOIN KHATAMST km ON pod.Kh_Code = km.KH_CODE
                LEFT JOIN LABOURMST lm ON pod.DEP_CODE = lm.LAB_CODE
                LEFT JOIN UNITMST convU ON pod.POD_ConvUOM = convU.UNIT_CODE
                LEFT JOIN LOCATIONMST makerLoc ON pod.POD_MakeID = makerLoc.LOC_CODE AND makerLoc.MODE = 'MAKER'
                WHERE LTRIM(RTRIM(pod.po_no)) = @PoNo
                ORDER BY pod.SrNo;";

            const string chargesSql = @"
                SELECT cd.Id AS Id, cd.Chg_Id AS ChgId, ISNULL(cm.CHG_NAME, '') AS ChgName,
                       cd.Code AS Code, ISNULL(cd.per, 0) AS Per, ISNULL(cd.Amt, 0) AS Amt,
                       ISNULL(cd.Mode, 'PURCHASE') AS Mode,
                       CASE 
                           WHEN LTRIM(RTRIM(cm.ADDLESS)) = '-' OR LTRIM(RTRIM(cm.ADDLESS)) = '-1' THEN CAST(-1 AS SMALLINT) 
                           ELSE CAST(1 AS SMALLINT) 
                       END AS AddLess,
                       ISNULL(cm.EXP, '') AS Exp, ISNULL(cd.Remark, '') AS Remark
                FROM ChargesDet cd
                LEFT JOIN CHARGESMST cm ON cd.Chg_Id = cm.CHG_ID
                WHERE LTRIM(RTRIM(cd.Code)) = @PoNo AND cd.Mode = 'PURCHASE'
                ORDER BY cm.PRIORITY;";

            const string conditionsSql = @"
                SELECT ConId AS ConId, ISNULL(Con_No, 0) AS ConNo, Code AS Code, '' AS ConditionText
                FROM ConditionDet
                WHERE LTRIM(RTRIM(Code)) = @PoNo
                ORDER BY Con_No;";

            using var conn = CreateConnection();
            var header = await conn.QueryFirstOrDefaultAsync<PurchaseOrderHeaderDto>(headerSql, new { PoNo = poNo });
            if (header == null) return null;

            header.Items = (await conn.QueryAsync<PurchaseOrderItemDto>(itemsSql, new { PoNo = poNo })).ToList();
            header.Charges = (await conn.QueryAsync<PurchaseOrderChargeDto>(chargesSql, new { PoNo = poNo })).ToList();
            header.Conditions = (await conn.QueryAsync<PurchaseOrderConditionDto>(conditionsSql, new { PoNo = poNo })).ToList();

            return header;
        }

        public async Task<PurchaseOrderPagedResult<SupplierLookupDto>> GetSuppliersLookupAsync(string search, int page, int pageSize)
        {
            const string countSql = @"
                SELECT COUNT(1)
                FROM PARTYMST AS A 
                LEFT JOIN GROUPMST AS B ON A.P_GRCODE=B.GR_CODE 
                WHERE (A.P_GRCODE=4 OR CHARINDEX('CRE', B.GR_NAME) > 0) 
                  AND B.GR_GPNP='BALANCE SHEET' 
                  AND (A.P_GRCODE=4 OR A.P_GST_STATE<>'') 
                  AND (A.P_VIEW IS NULL OR A.P_VIEW<>'UNSEEN')
                  AND (@Search = '' OR A.P_NAME LIKE '%' + @Search + '%' OR A.P_GST_IN LIKE '%' + @Search + '%');";

            const string dataSql = @"
                SELECT A.P_CODE AS PCode, A.P_NAME AS PName, ISNULL(A.P_GST_IN, '') AS Gstin,
                       ISNULL(A.P_GST_STATE, '') AS StateCode, ISNULL(A.P_GST_REGADD, '') AS Address,
                       ISNULL(A.P_BRCODE, 0) AS BrkCode, ISNULL(C.BR_NAME, '') AS Agent,
                       CAST(ISNULL(A.P_CrDay, 0) AS INT) AS CreditDays,
                       CASE WHEN A.P_GST_TYPE=2 THEN 'TAXABLE' 
                            WHEN A.P_GST_TYPE=1 THEN 'UNDER COMPOSITION LIMIT' 
                            WHEN A.P_GST_TYPE=3 THEN 'CONSUMABLE' 
                            WHEN A.P_GST_TYPE=0 THEN 'UNREGISTERED' 
                            WHEN A.P_GST_TYPE=4 THEN 'EXPORT' 
                            ELSE 'NO-SPECIFIED' END AS TypeOfRegistrant
                FROM PARTYMST AS A 
                LEFT JOIN GROUPMST AS B ON A.P_GRCODE=B.GR_CODE 
                LEFT JOIN BROKERMST AS C ON A.P_BRCODE=C.BR_CODE 
                WHERE (A.P_GRCODE=4 OR CHARINDEX('CRE', B.GR_NAME) > 0) 
                  AND B.GR_GPNP='BALANCE SHEET' 
                  AND (A.P_GRCODE=4 OR A.P_GST_STATE<>'') 
                  AND (A.P_VIEW IS NULL OR A.P_VIEW<>'UNSEEN')
                  AND (@Search = '' OR A.P_NAME LIKE '%' + @Search + '%' OR A.P_GST_IN LIKE '%' + @Search + '%')
                ORDER BY A.P_NAME
                OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;";

            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 200);
            var offset = (page - 1) * pageSize;
            var cleanSearch = search?.Trim() ?? string.Empty;

            using var conn = CreateConnection();
            var totalCount = await conn.ExecuteScalarAsync<int>(countSql, new { Search = cleanSearch });
            var items = (await conn.QueryAsync<SupplierLookupDto>(dataSql, new { Search = cleanSearch, Offset = offset, PageSize = pageSize })).ToList();

            return new PurchaseOrderPagedResult<SupplierLookupDto>
            {
                Items = items,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            };
        }

        public async Task<PurchaseOrderPagedResult<ItemLookupDto>> GetItemsLookupAsync(string search, int page, int pageSize)
        {
            const string countSql = @"
                SELECT COUNT(1)
                FROM ITEMMST AS IM 
                WHERE IM.I_HSN<>'' AND (IM.I_BLOCK IS NULL OR IM.I_BLOCK=0)  
                  AND IM.I_HSN NOT LIKE '99%' AND IM.I_CODE NOT LIKE 'SAC%'
                  AND (@Search = '' OR IM.I_CODE LIKE '%' + @Search + '%' OR IM.I_NAME1 LIKE '%' + @Search + '%');";

            const string dataSql = @"
                SELECT IM.I_CODE AS ICode, IM.I_NAME1 AS ItName, ISNULL(UM.UNIT_CODE, 0) AS UnitCode, ISNULL(UM.UNIT_NAME, '') AS UnitName,
                       ISNULL(IM.I_RQTY, 0) AS Stock, ISNULL(CAT.CAT_NAME, '') AS CatName, ISNULL(IM.I_CID, 0) AS CatCode,
                       ISNULL(IM.I_HSN, '') AS Hsn, ISNULL(D.TAX_IGPER, 0) AS TaxSlab,
                       ISNULL(L.SKU_SHADENM, '') AS Shade,
                       CASE WHEN J.UNIT_CODE IS NULL OR J.UNIT_CODE=0 THEN ISNULL(UM.UNIT_CODE, 0) ELSE J.UNIT_CODE END AS SecUcode,
                       CASE WHEN J.UNIT_CODE IS NULL OR J.UNIT_CODE=0 THEN ISNULL(UM.UNIT_NAME, '') ELSE J.UNIT_NAME END AS SecUnit,
                       ISNULL(C.SIM_CONVQTY, 1) AS Conversion,
                       ISNULL(L.SKU_QNAME, '') AS Design,
                       ISNULL(L.SKU_GLUE,'') + '-' + ISNULL(L.SKU_PATTERN,'') AS Style,
                       ISNULL(L.SKU_GRADE, '') AS Size,
                       CASE WHEN CAT.SIZE_REQ = 'YES' OR CAT.SIZE_REQ = '1' THEN 1 ELSE 0 END AS SizeReq,
                       CASE WHEN CAT.GRADE_REQ = 'YES' OR CAT.GRADE_REQ = '1' THEN 1 ELSE 0 END AS GradeReq
                FROM ITEMMST AS IM 
                LEFT OUTER JOIN UNITMST AS UM ON UM.UNIT_CODE = IM.I_UOM 
                LEFT JOIN CATEGORYMST AS CAT ON IM.I_CID=CAT.CAT_CODE 
                LEFT JOIN TAX_SLAB_MST AS D ON IM.I_TAXSLAB=D.TAX_CODE 
                LEFT JOIN SUBITEMMST AS C ON IM.I_CODE=C.SIM_CODE 
                LEFT JOIN UNITMST AS J ON C.SIM_SECUNIT=J.UNIT_CODE 
                LEFT JOIN SKUMST AS L ON IM.I_CODE=L.SKU_CODE 
                WHERE IM.I_HSN<>'' AND (IM.I_BLOCK IS NULL OR IM.I_BLOCK=0)  
                  AND IM.I_HSN NOT LIKE '99%' AND IM.I_CODE NOT LIKE 'SAC%'
                  AND (@Search = '' OR IM.I_CODE LIKE '%' + @Search + '%' OR IM.I_NAME1 LIKE '%' + @Search + '%')
                ORDER BY IM.I_NAME1
                OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;";

            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 200);
            var offset = (page - 1) * pageSize;
            var cleanSearch = search?.Trim() ?? string.Empty;

            using var conn = CreateConnection();
            var totalCount = await conn.ExecuteScalarAsync<int>(countSql, new { Search = cleanSearch });
            var items = (await conn.QueryAsync<ItemLookupDto>(dataSql, new { Search = cleanSearch, Offset = offset, PageSize = pageSize })).ToList();

            return new PurchaseOrderPagedResult<ItemLookupDto>
            {
                Items = items,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            };
        }

        public async Task<List<ItemMergeLookupDto>> GetItemMergesAsync(string itemCode)
        {
            if (string.IsNullOrWhiteSpace(itemCode)) return new List<ItemMergeLookupDto>();

            const string sql = @"
                SELECT IMR_MRGNO AS MergeLotNo, ISNULL(IMR_SHADE, '') AS Shade, 
                       ISNULL(IMR_MAKER, '') AS Maker, ISNULL(IMR_PCODE, 0) AS MakerCode
                FROM ITEMMARGE 
                WHERE I_CODE = @ItemCode AND (IMR_VIEW IS NULL OR IMR_VIEW<>'UNSEEN') 
                ORDER BY IMR_MRGNO, IMR_SHADE;";

            using var conn = CreateConnection();
            return (await conn.QueryAsync<ItemMergeLookupDto>(sql, new { ItemCode = itemCode.Trim() })).ToList();
        }

        public async Task<List<string>> GetShadesAsync()
        {
            const string sql = @"
                SELECT DISTINCT PSHADE_CODE 
                FROM PKSHADE 
                WHERE (PSHADE_ACTIVE=0 OR PSHADE_ACTIVE IS NULL) 
                ORDER BY PSHADE_CODE;";

            using var conn = CreateConnection();
            return (await conn.QueryAsync<string>(sql)).ToList();
        }

        public async Task<PurchaseOrderLookupsDto> GetLookupsAsync()
        {
            using var conn = CreateConnection();

            const string storesSql = "SELECT STR_NAME AS StrName, STR_CODE AS StrCode FROM STOREMST WHERE STR_NAME<>'' ORDER BY STR_NAME;";
            const string currSql = "SELECT DISTINCT(CURR) FROM PUR_ORD_MST WHERE CURR IS NOT NULL AND CURR <> '' ORDER BY CURR;";
            const string capModeSql = "SELECT LOC_CODE AS LocCode, LOCATION AS Location FROM LOCATIONMST WHERE MODE = 'CAPCONS' ORDER BY LOCATION;";
            const string deptsSql = "SELECT LAB_CODE AS LabCode, LAB_NAME AS LabName FROM LABOURMST WHERE (LAB_STATUS='' OR LAB_STATUS IS NULL OR LAB_STATUS='YES') ORDER BY LAB_NAME;";
            const string divisionsSql = "SELECT KH_NAME AS KhName, KH_CODE AS KhCode FROM KHATAMST CROSS APPLY DBO.FNSPLITSTRING(KH_BRANCH,',') WHERE SPLITDATA='1' AND (KH_DISPLAY IS NULL OR KH_DISPLAY=0) ORDER BY KH_NAME;";
            const string chargesSql = @"
                SELECT PRIORITY AS Priority, CHG_ID AS ChgId, CHG_NAME AS ChgName, ISNULL(DISC, 0) AS Disc,
                       CASE 
                           WHEN LTRIM(RTRIM(ADDLESS)) = '-' OR LTRIM(RTRIM(ADDLESS)) = '-1' THEN CAST(-1 AS SMALLINT) 
                           ELSE CAST(1 AS SMALLINT) 
                       END AS AddLess,
                       ISNULL(EXP, '') AS Exp
                FROM CHARGESMST
                WHERE LOC <> 0 AND CHG_PO <> 0
                ORDER BY PRIORITY;";
            const string dTermsSql = "SELECT TOP 30 DTERMS FROM PUR_ORD_MST WHERE DTERMS IS NOT NULL AND DTERMS <> '' GROUP BY DTERMS ORDER BY DTERMS;";
            const string pTermsSql = "SELECT TOP 30 PTERMS FROM PUR_ORD_MST WHERE PTERMS IS NOT NULL AND PTERMS <> '' GROUP BY PTERMS ORDER BY PTERMS;";
            const string dispInsSql = "SELECT TOP 30 DISP_INS FROM PUR_ORD_MST WHERE DISP_INS IS NOT NULL AND DISP_INS <> '' GROUP BY DISP_INS ORDER BY DISP_INS;";
            const string spNoteSql = "SELECT TOP 30 SP_NOTE FROM PUR_ORD_MST WHERE SP_NOTE IS NOT NULL AND SP_NOTE <> '' GROUP BY SP_NOTE ORDER BY SP_NOTE;";
            const string remarkSql = "SELECT TOP 30 REMARK FROM PUR_ORD_MST WHERE REMARK IS NOT NULL AND REMARK <> '' GROUP BY REMARK ORDER BY REMARK;";
            const string busyStateSql = "SELECT ISNULL(BY_ADD2, '27') FROM BUSYMST WHERE BY_CODE = 1;";

            var stores = (await conn.QueryAsync<StoreLookupDto>(storesSql)).ToList();
            var currencies = (await conn.QueryAsync<string>(currSql)).ToList();
            var capModes = (await conn.QueryAsync<CapModeLookupDto>(capModeSql)).ToList();
            var depts = (await conn.QueryAsync<DepartmentLookupDto>(deptsSql)).ToList();
            var divisions = (await conn.QueryAsync<DivisionLookupDto>(divisionsSql)).ToList();
            var charges = (await conn.QueryAsync<ChargesMasterLookupDto>(chargesSql)).ToList();
            var dTerms = (await conn.QueryAsync<string>(dTermsSql)).ToList();
            var pTerms = (await conn.QueryAsync<string>(pTermsSql)).ToList();
            var dispIns = (await conn.QueryAsync<string>(dispInsSql)).ToList();
            var spNotes = (await conn.QueryAsync<string>(spNoteSql)).ToList();
            var remarks = (await conn.QueryAsync<string>(remarkSql)).ToList();
            var compState = await conn.ExecuteScalarAsync<string>(busyStateSql) ?? "27";

            // Next PO Number preview
            var nextPoNo = await GenerateNextPoNumberInternalAsync(conn, null);

            return new PurchaseOrderLookupsDto
            {
                NextPoNo = nextPoNo,
                CompanyStateCode = compState,
                Stores = stores,
                Currencies = currencies,
                CapModes = capModes,
                Departments = depts,
                Divisions = divisions,
                DefaultCharges = charges,
                DeliveryTermsSuggestions = dTerms,
                PaymentTermsSuggestions = pTerms,
                DispatchInstructionsSuggestions = dispIns,
                SpecialNotesSuggestions = spNotes,
                RemarksSuggestions = remarks
            };
        }

        public async Task<bool> IsDateLockedAsync(DateTime poDate)
        {
            const string sql = "SELECT COUNT(1) FROM LOCKDATAMST WHERE CAST(@PoDate AS DATE) = CAST(LDM_STDT AS DATE);";
            using var conn = CreateConnection();
            var count = await conn.ExecuteScalarAsync<int>(sql, new { PoDate = poDate.Date });
            return count > 0;
        }

        private static async Task<string> GenerateNextPoNumberInternalAsync(IDbConnection conn, IDbTransaction? tx)
        {
            var today = await conn.ExecuteScalarAsync<DateTime>("SELECT GETDATE();", transaction: tx);
            var fyStartYear = today.Month >= 4 ? today.Year : today.Year - 1;
            var fyStart = new DateTime(fyStartYear, 4, 1);
            var fySuffix = ((fyStartYear + 1) % 100).ToString("D2");

            var lockHint = tx != null ? "WITH (UPDLOCK, HOLDLOCK)" : "WITH (NOLOCK)";
            var maxSql = $@"
                SELECT ISNULL(MAX(TRY_CAST(SUBSTRING(PO_NO, 6, 6) AS INT)), 0) 
                FROM PUR_ORD_MST {lockHint}
                WHERE LEFT(PO_NO, 4) = 'PRCH' AND PO_DATE >= @FyStart;";

            var maxNum = await conn.ExecuteScalarAsync<int>(maxSql, new { FyStart = fyStart }, tx);
            var nextNum = maxNum + 1;
            return $"PRCH/{nextNum:D6}/{fySuffix}";
        }

        public async Task<string> SavePurchaseOrderAsync(PurchaseOrderSaveRequest request, string username)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.Items == null || request.Items.Count == 0)
            {
                throw new InvalidOperationException("At least one line item is required to save a Purchase Order.");
            }
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Username is required for audit logging.", nameof(username));
            }

            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);

            using var conn = (SqlConnection)CreateConnection();
            await conn.OpenAsync();
            using var tx = conn.BeginTransaction();

            try
            {
                // 1. Pre-save Date Lock Check
                const string lockCheckSql = "SELECT COUNT(1) FROM LOCKDATAMST WHERE CAST(@PoDate AS DATE) = CAST(LDM_STDT AS DATE);";
                var lockCount = await conn.ExecuteScalarAsync<int>(lockCheckSql, new { PoDate = request.PoDate.Date }, tx);
                if (lockCount > 0)
                {
                    throw new InvalidOperationException($"The date {request.PoDate:yyyy-MM-dd} is locked in LOCKDATAMST. Action rejected.");
                }

                // 2. Resolve PO Number (Generate if new, or use existing if edit)
                string poNo = request.PoNo?.Trim() ?? string.Empty;
                bool isNew = string.IsNullOrWhiteSpace(poNo);

                if (!isNew)
                {
                    const string checkExistsSql = "SELECT COUNT(1) FROM Pur_Ord_Mst WHERE Po_No = @PoNo;";
                    var exists = await conn.ExecuteScalarAsync<int>(checkExistsSql, new { PoNo = poNo }, tx) > 0;
                    if (!exists)
                    {
                        isNew = true;
                    }
                }

                if (isNew)
                {
                    if (string.IsNullOrWhiteSpace(poNo))
                    {
                        poNo = await GenerateNextPoNumberInternalAsync(conn, tx);
                    }
                }
                else
                {
                    // If editing, check if already received or closed
                    const string checkStateSql = "SELECT CAST(ISNULL(Approved, 0) AS INT) AS Approved, CAST(ISNULL(IsRec, 0) AS INT) AS IsRec, CAST(ISNULL(ClosePO, 0) AS INT) AS ClosePO FROM Pur_Ord_Mst WHERE Po_No = @PoNo;";
                    var state = await conn.QueryFirstOrDefaultAsync<dynamic>(checkStateSql, new { PoNo = poNo }, tx);
                    if (state != null)
                    {
                        int closeVal = 0;
                        try { closeVal = Convert.ToInt32(state.ClosePO); } catch { }
                        if (closeVal != 0)
                        {
                            throw new InvalidOperationException($"Purchase Order '{poNo}' is CLOSED and cannot be modified.");
                        }
                    }
                }

                // Delete existing child records uniformly (matches legacy queries 58, 62, 63, 64)
                await conn.ExecuteAsync("DELETE FROM ChargesDet WHERE mode = 'PURCHASE' AND Code = @PoNo;", new { PoNo = poNo }, tx);
                await conn.ExecuteAsync("DELETE FROM ConditionDet WHERE Code = @PoNo;", new { PoNo = poNo }, tx);
                await conn.ExecuteAsync("DELETE FROM Pur_Ordr_Det WHERE po_no = @PoNo;", new { PoNo = poNo }, tx);
                await conn.ExecuteAsync("DELETE FROM stockregnew WHERE SR_Code = @PoNo AND mode IN ('PO');", new { PoNo = poNo }, tx);

                // 3. Resolve Party Name for DAYBOOK
                const string partyNameSql = "SELECT P_NAME FROM PARTYMST WHERE P_CODE = @PCode;";
                var partyName = await conn.ExecuteScalarAsync<string>(partyNameSql, new { PCode = request.PCode }, tx) ?? "SUPPLIER";

                // 4. DAYBOOK Audit Trail
                const string daybookSql = @"
                    INSERT INTO DAYBOOK(DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES(GETDATE(), @DbUser, @PName, @Amt, @RefNo, @Action, 'P.O', 1, @CompanyName);";

                var action = isNew ? "NEW" : "EDIT";

                // Audit row 1: Supplier & Net Amount
                await conn.ExecuteAsync(daybookSql, new
                {
                    DbUser = username.Trim(),
                    PName = partyName,
                    Amt = request.NetAmt,
                    RefNo = poNo,
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
                        RefNo = poNo,
                        Action = action,
                        CompanyName = companyName
                    }, tx);
                }

                // 5. Header Insert / Update
                if (isNew)
                {
                    const string insertHeaderSql = @"
                        INSERT INTO Pur_Ord_Mst (
                            PO_No, PO_Date, P_Code, PO_DelCd, P_Str_Code, Dept_Code, PO_Mode,
                            Tot_Itm, Tot_Qty, Tot_Disc, Tot_Amt, PF_Chg, Excise, Lst_Chst, Freight,
                            Insurance, Others, EDCass, NetAmt, DTerms, PTerms, Disp_Ins, Sp_Note,
                            Remark, isImp, Curr, Words, Supp_Ref, Recdate, PO_CrDays, POM_LOC,
                            POM_EDate, POM_UsrName, POM_EMode, POM_DELDays, POM_CapMode, TypeID,
                            isGE, ClosePO, Approved, isrec, CGPER, CGAMT, SGPER, SGAMT, IGPER,
                            IGAMT, POM_AddCD, POM_BrCode, POM_IsFreight
                        ) VALUES (
                            @PoNo, @PoDate, @PCode, @PoDelCd, @PStrCode, @DeptCode, @PoMode,
                            @TotItm, @TotQty, @TotDisc, @TotAmt, @PfChg, 0, 0, @Freight,
                            @Insurance, @Others, 0, @NetAmt, @DTerms, @PTerms, @DispIns, @SpNote,
                            @Remark, @IsImp, @Curr, @Words, @SuppRef, @RecDate, @PoCrDays, 'LWHL26_SQL',
                            GETDATE(), @UsrName, 'New', @PomDelDays, @PomCapMode, 0,
                            0, 0, 0, 0, @CgPer, @CgAmt, @SgPer, @SgAmt, @IgPer,
                            @IgAmt, 0, @PomBrCode, @PomIsFreight
                        );";

                    await conn.ExecuteAsync(insertHeaderSql, new
                    {
                        PoNo = poNo,
                        PoDate = request.PoDate.Date,
                        request.PCode,
                        PoDelCd = request.PoDelCd > 0 ? request.PoDelCd : request.PCode,
                        request.PStrCode,
                        request.DeptCode,
                        PoMode = string.IsNullOrWhiteSpace(request.PoMode) ? "Direct" : request.PoMode,
                        TotItm = (short)request.Items.Count,
                        request.TotQty,
                        request.TotDisc,
                        request.TotAmt,
                        request.PfChg,
                        request.Freight,
                        request.Insurance,
                        request.Others,
                        request.NetAmt,
                        request.DTerms,
                        request.PTerms,
                        request.DispIns,
                        request.SpNote,
                        request.Remark,
                        IsImp = request.IsImp ? 1 : 0,
                        request.Curr,
                        request.Words,
                        request.SuppRef,
                        request.RecDate,
                        request.PoCrDays,
                        UsrName = username.Trim(),
                        request.PomDelDays,
                        request.PomCapMode,
                        request.CgPer,
                        request.CgAmt,
                        request.SgPer,
                        request.SgAmt,
                        request.IgPer,
                        request.IgAmt,
                        PomBrCode = request.PomBrCode > 0 ? request.PomBrCode : 1,
                        request.PomIsFreight
                    }, tx);
                }
                else
                {
                    const string updateHeaderSql = @"
                        UPDATE Pur_Ord_Mst SET
                            PO_Date = @PoDate, P_Code = @PCode, PO_DelCd = @PoDelCd, P_Str_Code = @PStrCode,
                            Dept_Code = @DeptCode, PO_Mode = @PoMode, Tot_Itm = @TotItm, Tot_Qty = @TotQty,
                            Tot_Disc = @TotDisc, Tot_Amt = @TotAmt, PF_Chg = @PfChg, Freight = @Freight,
                            Insurance = @Insurance, Others = @Others, NetAmt = @NetAmt, DTerms = @DTerms,
                            PTerms = @PTerms, Disp_Ins = @DispIns, Sp_Note = @SpNote, Remark = @Remark,
                            isImp = @IsImp, Curr = @Curr, Words = @Words, Supp_Ref = @SuppRef,
                            Recdate = @RecDate, PO_CrDays = @PoCrDays, POM_EDate = GETDATE(),
                            POM_UsrName = @UsrName, POM_EMode = 'Edit', POM_DELDays = @PomDelDays,
                            POM_CapMode = @PomCapMode, CGPER = @CgPer, CGAMT = @CgAmt, SGPER = @SgPer,
                            SGAMT = @SgAmt, IGPER = @IgPer, IGAMT = @IgAmt, POM_BrCode = @PomBrCode,
                            POM_IsFreight = @PomIsFreight
                        WHERE Po_No = @PoNo;";

                    await conn.ExecuteAsync(updateHeaderSql, new
                    {
                        PoNo = poNo,
                        PoDate = request.PoDate.Date,
                        request.PCode,
                        PoDelCd = request.PoDelCd > 0 ? request.PoDelCd : request.PCode,
                        request.PStrCode,
                        request.DeptCode,
                        PoMode = string.IsNullOrWhiteSpace(request.PoMode) ? "Direct" : request.PoMode,
                        TotItm = (short)request.Items.Count,
                        request.TotQty,
                        request.TotDisc,
                        request.TotAmt,
                        request.PfChg,
                        request.Freight,
                        request.Insurance,
                        request.Others,
                        request.NetAmt,
                        request.DTerms,
                        request.PTerms,
                        request.DispIns,
                        request.SpNote,
                        request.Remark,
                        IsImp = request.IsImp ? 1 : 0,
                        request.Curr,
                        request.Words,
                        request.SuppRef,
                        request.RecDate,
                        request.PoCrDays,
                        UsrName = username.Trim(),
                        request.PomDelDays,
                        request.PomCapMode,
                        request.CgPer,
                        request.CgAmt,
                        request.SgPer,
                        request.SgAmt,
                        request.IgPer,
                        request.IgAmt,
                        PomBrCode = request.PomBrCode > 0 ? request.PomBrCode : 1,
                        request.PomIsFreight
                    }, tx);
                }

                // 6. Insert Line Items into Pur_Ordr_Det
                const string insertDetSql = @"
                    INSERT INTO Pur_Ordr_Det (
                        po_no, SrNo, Ind_Code, Quo_Code, I_Code, UOM, Qty, Rate, Disc, Amount,
                        Kh_Code, ExRate, ExAmt, Dep_Code, isGe, ClosePO, IsAppro, IsRec, IsReject,
                        IsHold, mrgno, Shade, P_Remark, Specification, freight, POD_IsFreight,
                        CGPer, CGAmt, SGPer, SGAmt, IGPer, IGAmt, accqty, POD_STOCK, POD_LASTRATE,
                        POD_MakeID, POD_ConvUOM, POD_ConvQty
                    ) VALUES (
                        @PoNo, @SrNo, 'None', 'None', @ICode, @Uom, @Qty, @Rate, @Disc, @Amount,
                        @KhCode, 0, @Amount, @DepCode, 0, 0, 0, 0, 0,
                        0, @MrgNo, @Shade, @PRemark, @Specification, @Freight, @PodIsFreight,
                        @CgPer, @CgAmt, @SgPer, @SgAmt, @IgPer, @IgAmt, 0, @PodStock, @PodLastRate,
                        @PodMakeId, @PodConvUom, @PodConvQty
                    );";

                int sr = 1;
                foreach (var it in request.Items)
                {
                    await conn.ExecuteAsync(insertDetSql, new
                    {
                        PoNo = poNo,
                        SrNo = sr++,
                        ICode = string.IsNullOrWhiteSpace(it.ICode) ? "ITEM" : it.ICode,
                        Uom = it.Uom > 0 ? it.Uom : 1,
                        it.Qty,
                        it.Rate,
                        it.Disc,
                        it.Amount,
                        KhCode = it.KhCode > 0 ? it.KhCode : 1,
                        DepCode = it.DepCode > 0 ? it.DepCode : 1,
                        MrgNo = it.MrgNo ?? string.Empty,
                        Shade = string.IsNullOrWhiteSpace(it.Shade) ? "*" : it.Shade,
                        PRemark = it.PRemark ?? string.Empty,
                        Specification = it.Specification ?? string.Empty,
                        it.Freight,
                        it.PodIsFreight,
                        it.CgPer,
                        it.CgAmt,
                        it.SgPer,
                        it.SgAmt,
                        it.IgPer,
                        it.IgAmt,
                        it.PodStock,
                        it.PodLastRate,
                        it.PodMakeId,
                        PodConvUom = it.PodConvUom > 0 ? it.PodConvUom : (it.Uom > 0 ? it.Uom : 1),
                        it.PodConvQty
                    }, tx);
                }

                // 7. Insert Charges into ChargesDet
                const string maxChargeIdSql = "SELECT ISNULL(MAX(Id), 0) FROM ChargesDet WITH (UPDLOCK, HOLDLOCK);";
                var curChargeId = await conn.ExecuteScalarAsync<int>(maxChargeIdSql, transaction: tx);
                const string insertChargeSql = @"
                    INSERT INTO ChargesDet (Id, Chg_Id, Code, Per, Amt, Mode, IIND, Remark)
                    VALUES (@Id, @ChgId, @Code, @Per, @Amt, 'PURCHASE', -1, @Remark);";

                foreach (var chg in request.Charges)
                {
                    curChargeId++;
                    await conn.ExecuteAsync(insertChargeSql, new
                    {
                        Id = curChargeId,
                        chg.ChgId,
                        Code = poNo,
                        chg.Per,
                        chg.Amt,
                        Remark = chg.Remark ?? string.Empty
                    }, tx);
                }

                // 8. Insert Conditions into ConditionDet
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
                        Code = poNo
                    }, tx);
                }

                // 9. Update Stock Commitment in stockregnew
                const string stockRegSql = @"
                    INSERT INTO stockregnew (
                        dt, I_Code, I_Qty, MrgNo, Priority, SR_Code, P_Name, Amt, SR_Stk,
                        Mode, kh_Code, SR_chg, SR_Srno, PO_NO, IsClose, TypeID, PR_ID,
                        mat_unit, mat_other, Store_ID, Stk_DivID
                    )
                    SELECT POM.PO_Date, POD.I_Code, POD.Qty, '', 15, POM.po_no, PM.P_Name,
                           POD.Amount, 'N', 'PO', ISNULL(NULLIF(POD.dep_Code, 0), 1), 0, POD.P_Id, POM.PO_NO,
                           ISNULL(POM.closePO, 0) * -1, ISNULL(POM.TYPEID, 0), POM.p_code,
                           CASE WHEN ISNULL(POD.uom, 0) = 0 THEN 1 ELSE POD.uom END, '', ISNULL(NULLIF(POM.p_str_code, 0), 1), ISNULL(NULLIF(POD.kh_code, 0), 1)
                    FROM Pur_Ord_mst POM
                    JOIN Pur_ordr_det POD ON POM.PO_No = POD.PO_No
                    LEFT JOIN partymst PM ON PM.p_code = POM.p_code
                    WHERE POM.PO_NO = @PoNo;";

                await conn.ExecuteAsync(stockRegSql, new { PoNo = poNo }, tx);

                tx.Commit();
                return poNo;
            }
            catch
            {
                tx.Rollback();
                throw;
            }
        }

        public async Task<bool> DeletePurchaseOrderAsync(string poNo, string username)
        {
            if (string.IsNullOrWhiteSpace(poNo)) return false;
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Username is required for audit logging.", nameof(username));
            }

            poNo = Uri.UnescapeDataString(poNo).Trim();

            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);

            using var conn = (SqlConnection)CreateConnection();
            await conn.OpenAsync();
            using var tx = conn.BeginTransaction();

            try
            {
                // 1. Verify existence & eligibility
                const string checkSql = @"
                    SELECT pom.PO_Date, pom.NetAmt, ISNULL(pm.P_Name, 'SUPPLIER') AS PartyName,
                           CAST(ISNULL(pom.Approved, 0) AS BIT) AS Approved,
                           CAST(ISNULL(pom.IsRec, 0) AS BIT) AS IsRec,
                           CAST(ISNULL(pom.ClosePO, 0) AS BIT) AS ClosePO
                    FROM Pur_Ord_Mst pom
                    LEFT JOIN partymst pm ON pom.P_Code = pm.P_Code
                    WHERE LTRIM(RTRIM(pom.Po_No)) = @PoNo;";

                var po = await conn.QueryFirstOrDefaultAsync<dynamic>(checkSql, new { PoNo = poNo }, tx);
                if (po == null)
                {
                    throw new KeyNotFoundException($"Purchase Order '{poNo}' was not found.");
                }

                int recVal = 0;
                try { recVal = Convert.ToInt32(po.IsRec); } catch { }

                if (recVal != 0)
                {
                    throw new InvalidOperationException($"Purchase Order '{poNo}' has Goods Receipt Notes (GRN) and cannot be deleted.");
                }

                DateTime poDate = (DateTime)po.PO_Date;
                const string lockCheckSql = "SELECT COUNT(1) FROM LOCKDATAMST WHERE CAST(@PoDate AS DATE) = CAST(LDM_STDT AS DATE);";
                var lockCount = await conn.ExecuteScalarAsync<int>(lockCheckSql, new { PoDate = poDate.Date }, tx);
                if (lockCount > 0)
                {
                    throw new InvalidOperationException($"The date {poDate:yyyy-MM-dd} is locked in LOCKDATAMST. Deletion rejected.");
                }

                // 2. DAYBOOK audit logging
                const string daybookSql = @"
                    INSERT INTO DAYBOOK(DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME)
                    VALUES(GETDATE(), @DbUser, @PName, @Amt, @RefNo, 'DELETE', 'P.O', 1, @CompanyName);";

                await conn.ExecuteAsync(daybookSql, new
                {
                    DbUser = username.Trim(),
                    PName = (string)po.PartyName,
                    Amt = (double)po.NetAmt,
                    RefNo = poNo,
                    CompanyName = companyName
                }, tx);

                // 3. Delete records (including advances, stockreg commitments, charges, conditions, and items)
                await conn.ExecuteAsync("DELETE FROM POADVANCEMST WHERE LTRIM(RTRIM(PO_NO)) = @PoNo;", new { PoNo = poNo }, tx);
                await conn.ExecuteAsync("DELETE FROM stockregnew WHERE LTRIM(RTRIM(SR_Code)) = @PoNo AND mode IN ('PO');", new { PoNo = poNo }, tx);
                await conn.ExecuteAsync("DELETE FROM ChargesDet WHERE mode = 'PURCHASE' AND LTRIM(RTRIM(Code)) = @PoNo;", new { PoNo = poNo }, tx);
                await conn.ExecuteAsync("DELETE FROM ConditionDet WHERE LTRIM(RTRIM(Code)) = @PoNo;", new { PoNo = poNo }, tx);
                await conn.ExecuteAsync("DELETE FROM Pur_Ordr_Det WHERE LTRIM(RTRIM(po_no)) = @PoNo;", new { PoNo = poNo }, tx);
                var rows = await conn.ExecuteAsync("DELETE FROM Pur_Ord_Mst WHERE LTRIM(RTRIM(Po_No)) = @PoNo;", new { PoNo = poNo }, tx);

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
