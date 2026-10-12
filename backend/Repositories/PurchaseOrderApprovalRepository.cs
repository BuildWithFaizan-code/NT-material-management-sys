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
    public class PurchaseOrderApprovalRepository : IPurchaseOrderApprovalRepository
    {
        private readonly string _connectionString;
        private readonly ILogger<PurchaseOrderApprovalRepository> _logger;

        public PurchaseOrderApprovalRepository(IConfiguration configuration, ILogger<PurchaseOrderApprovalRepository> logger)
        {
            _connectionString = DbConnectionHelper.ResolveConnectionString(configuration);
            _logger = logger;
        }

        private SqlConnection CreateConnection() => new(_connectionString);

        public async Task<PoApprovalLookupsDto> GetLookupsAsync()
        {
            using var conn = CreateConnection();
            await conn.OpenAsync();

            const string deptsSql = @"
                SELECT LAB_NAME AS LabName, LAB_CODE AS LabCode 
                FROM LABOURMST 
                WHERE (LAB_STATUS='' OR LAB_STATUS IS NULL OR LAB_STATUS='YES') 
                ORDER BY LAB_NAME;";

            const string plantsSql = @"
                SELECT STR_NAME AS StrName, STR_CODE AS StrCode 
                FROM STOREMST 
                WHERE STR_NAME<>'' 
                ORDER BY STR_NAME;";

            const string partiesSql = @"
                SELECT P_CODE AS PCode, P_NAME AS PName 
                FROM PARTYMST 
                WHERE P_CODE IN (SELECT DISTINCT A.P_CODE FROM PUR_ORD_MST AS A WHERE A.P_CODE IS NOT NULL AND A.P_CODE <> 0) 
                ORDER BY P_NAME;";

            var depts = (await conn.QueryAsync<PoApprovalDepartmentDto>(deptsSql)).ToList();
            var plants = (await conn.QueryAsync<PoApprovalPlantDto>(plantsSql)).ToList();
            var parties = (await conn.QueryAsync<PoApprovalSupplierDto>(partiesSql)).ToList();

            return new PoApprovalLookupsDto
            {
                Departments = depts,
                Plants = plants,
                Suppliers = parties
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

        public async Task<IEnumerable<PoApprovalRecordDto>> GetRecordsAsync(PoApprovalFilterQuery filter)
        {
            using var conn = CreateConnection();
            await conn.OpenAsync();

            var sb = new StringBuilder(@"
                SELECT 
                    A.PO_NO AS PurOrdNo, 
                    A.PO_DATE AS PoDate, 
                    ISNULL(A.SUPP_REF, '') AS RefNo, 
                    A.RECDATE AS RefDate, 
                    ISNULL(C.LAB_NAME, 'GENERAL') AS Department, 
                    ISNULL(B.DEP_CODE, 0) AS DeptCode, 
                    ISNULL(F.STR_NAME, 'MAIN') AS Plant, 
                    ISNULL(A.P_STR_CODE, 0) AS PlantCode, 
                    ISNULL(E.P_NAME, 'SUPPLIER') AS PartyName, 
                    ISNULL(A.P_CODE, 0) AS PartyCode, 
                    ISNULL(D.I_CODE, '') AS ItCode, 
                    ISNULL(D.I_NAME1, '') AS ItemName, 
                    ISNULL(B.SHADE, '') AS Shade, 
                    CAST(ISNULL(B.QTY, 0) AS DECIMAL(18,3)) AS PoQty, 
                    CAST(ISNULL(B.ACCQTY, 0) AS DECIMAL(18,3)) AS InwardQty, 
                    CAST(ISNULL(B.QTY, 0) - ISNULL(B.ACCQTY, 0) AS DECIMAL(18,3)) AS BalanceQty, 
                    CAST(ISNULL(B.RATE, 0) AS DECIMAL(18,3)) AS Rate, 
                    CAST(ISNULL(B.AMOUNT, 0) AS DECIMAL(18,2)) AS Amount, 
                    CAST(ISNULL(B.FREIGHT, 0) AS DECIMAL(18,2)) AS Freight, 
                    ISNULL(B.P_ID, 0) AS PId, 
                    CAST(ISNULL(B.ISAPPRO, 0) AS INT) AS IsAppro, 
                    CAST(ISNULL(B.ISREJECT, 0) AS INT) AS IsReject, 
                    CAST(ISNULL(B.ISHOLD, 0) AS INT) AS IsHold, 
                    CAST(ISNULL(B.CLOSEPO, 0) AS INT) AS ClosePo, 
                    ISNULL(B.IND_CODE, '') AS IndCode, 
                    ISNULL(B.POD_CLOSREM, '') AS PodClosRem, 
                    (SELECT MAX(GE_NO) FROM GATEENTRYDET AS GED WHERE GED.PO_NO = A.PO_NO AND GED.I_CODE = B.I_CODE AND GED.P_ID = B.P_ID) AS ProcessDo 
                FROM PUR_ORD_MST AS A 
                LEFT JOIN PUR_ORDR_DET AS B ON A.PO_NO = B.PO_NO 
                LEFT JOIN LABOURMST AS C ON B.DEP_CODE = C.LAB_CODE 
                LEFT JOIN ITEMMST AS D ON B.I_CODE = D.I_CODE  
                LEFT JOIN PARTYMST AS E ON A.P_CODE = E.P_CODE 
                LEFT JOIN STOREMST AS F ON A.P_STR_CODE = F.STR_CODE 
                WHERE A.PO_NO <> '' AND B.P_ID IS NOT NULL ");

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
                    sb.Append(" AND (B.CLOSEPO <> 0) ");
                    break;
                case "UNCLOSE":
                    sb.Append(" AND (B.CLOSEPO = 0 OR B.CLOSEPO IS NULL) ");
                    break;
                case "PENDING":
                case "FILTER_VIEW_ONLY":
                default:
                    sb.Append(@" AND (B.ISAPPRO = 0 OR B.ISAPPRO IS NULL) 
                                 AND (B.ISREJECT = 0 OR B.ISREJECT IS NULL) 
                                 AND (B.ISHOLD = 0 OR B.ISHOLD IS NULL) 
                                 AND (B.CLOSEPO = 0 OR B.CLOSEPO IS NULL) ");
                    break;
            }

            // Dynamic Filters
            if (filter.DeptCode.HasValue && filter.DeptCode.Value > 0)
            {
                sb.Append(" AND (B.DEP_CODE = @DeptCode OR A.DEPT_CODE = @DeptCode) ");
                parameters.Add("DeptCode", filter.DeptCode.Value);
            }

            if (filter.PlantCode.HasValue && filter.PlantCode.Value > 0)
            {
                sb.Append(" AND A.P_STR_CODE = @PlantCode ");
                parameters.Add("PlantCode", filter.PlantCode.Value);
            }

            if (filter.PartyCode.HasValue && filter.PartyCode.Value > 0)
            {
                sb.Append(" AND A.P_CODE = @PartyCode ");
                parameters.Add("PartyCode", filter.PartyCode.Value);
            }

            if (!string.IsNullOrWhiteSpace(filter.PoNo))
            {
                sb.Append(" AND A.PO_NO LIKE @PoNo ");
                parameters.Add("PoNo", $"%{filter.PoNo.Trim()}%");
            }

            if (!string.IsNullOrWhiteSpace(filter.ItemSearch))
            {
                sb.Append(" AND (D.I_CODE LIKE @ItemSearch OR D.I_NAME1 LIKE @ItemSearch) ");
                parameters.Add("ItemSearch", $"%{filter.ItemSearch.Trim()}%");
            }

            if (filter.FromDate.HasValue)
            {
                sb.Append(" AND A.PO_DATE >= @FromDate ");
                parameters.Add("FromDate", filter.FromDate.Value.Date);
            }

            if (filter.ToDate.HasValue)
            {
                sb.Append(" AND A.PO_DATE <= @ToDate ");
                parameters.Add("ToDate", filter.ToDate.Value.Date.AddDays(1).AddTicks(-1));
            }

            sb.Append(" ORDER BY A.PO_DATE DESC, A.PO_NO DESC, B.P_ID ASC;");

            return await conn.QueryAsync<PoApprovalRecordDto>(sb.ToString(), parameters);
        }

        public async Task<int> ExecuteStatusActionAsync(PoApprovalActionRequest request, string username, string companyName)
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
                string daybookType = "POA";

                switch (actionType.ToLowerInvariant())
                {
                    case "reject":
                        lineUpdateSql = @"
                            UPDATE Pur_Ordr_Det 
                            SET isAppro = 0, isReject = -1, isHold = 0, Closepo = 0, POD_ClosRem = @Remark 
                            WHERE PO_No = @PoNo AND P_Id = @PId;";
                        daybookAction = "REJECT";
                        break;

                    case "hold":
                        lineUpdateSql = @"
                            UPDATE Pur_Ordr_Det 
                            SET isAppro = 0, isReject = 0, isHold = -1, Closepo = 0, POD_ClosRem = @Remark 
                            WHERE PO_No = @PoNo AND P_Id = @PId;";
                        daybookAction = "HOLD";
                        break;

                    case "close":
                        lineUpdateSql = @"
                            UPDATE Pur_Ordr_Det 
                            SET Closepo = -1, POD_ClosRem = @Remark 
                            WHERE PO_No = @PoNo AND P_Id = @PId;";
                        daybookAction = "CLOSE";
                        break;

                    case "unclose":
                        lineUpdateSql = @"
                            UPDATE Pur_Ordr_Det 
                            SET Closepo = 0, POD_ClosRem = '' 
                            WHERE PO_No = @PoNo AND P_Id = @PId;";
                        daybookAction = "UNCLOSE";
                        break;

                    case "approve":
                    default:
                        lineUpdateSql = @"
                            UPDATE Pur_Ordr_Det 
                            SET isAppro = -1, isReject = 0, isHold = 0, Closepo = 0, PO_AppDt = @ApprovalDate, POD_ClosRem = @Remark 
                            WHERE PO_No = @PoNo AND P_Id = @PId;";
                        daybookAction = "";
                        break;
                }

                const string daybookSql = @"
                    INSERT INTO DAYBOOK (DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME) 
                    VALUES (GETDATE(), @ActingUser, @DepartmentName, 0, @PoNo, @DbAction, @DbTyp, 1, @CompanyName);";

                int affectedLines = 0;
                var touchedPoNos = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

                foreach (var item in request.Items)
                {
                    var updated = await conn.ExecuteAsync(lineUpdateSql, new
                    {
                        PoNo = item.PoNo,
                        PId = item.PId,
                        ApprovalDate = approvalDate,
                        Remark = remark
                    }, tx);

                    if (updated > 0)
                    {
                        affectedLines += updated;
                        touchedPoNos.Add(item.PoNo);

                        var deptName = string.IsNullOrWhiteSpace(item.DepartmentName) ? "REGULAR" : item.DepartmentName;
                        await conn.ExecuteAsync(daybookSql, new
                        {
                            ActingUser = username.Trim(),
                            DepartmentName = deptName,
                            PoNo = item.PoNo,
                            DbAction = daybookAction,
                            DbTyp = daybookType,
                            CompanyName = companyName
                        }, tx);
                    }
                }

                // Header Synchronization in Pur_Ord_Mst
                foreach (var poNo in touchedPoNos)
                {
                    // 1. Reset header if any unapproved item exists in this PO
                    const string resetHeaderSql = @"
                        UPDATE Pur_Ord_Mst 
                        SET Approved = 0, AppDate = NULL 
                        WHERE PO_No = @PoNo 
                          AND PO_No IN (SELECT DISTINCT PO_No FROM Pur_Ordr_Det WHERE isappro = 0 OR isappro IS NULL);";
                    await conn.ExecuteAsync(resetHeaderSql, new { PoNo = poNo }, tx);

                    // 2. Fully approve header if ALL items in this PO are approved
                    const string fullApproveHeaderSql = @"
                        UPDATE Pur_Ord_Mst 
                        SET Approved = -1, AppDate = @ApprovalDate 
                        WHERE PO_No = @PoNo 
                          AND PO_No IN (
                              SELECT DISTINCT PO_No 
                              FROM Pur_Ordr_Det AS a 
                              GROUP BY PO_No 
                              HAVING COUNT(PO_No) <= (SELECT COUNT(*) FROM Pur_Ordr_Det WHERE PO_No = a.PO_No AND isappro <> 0)
                          );";
                    await conn.ExecuteAsync(fullApproveHeaderSql, new { PoNo = poNo, ApprovalDate = approvalDate }, tx);

                    // 3. Close header if all items closed
                    if (actionType.Equals("close", StringComparison.OrdinalIgnoreCase))
                    {
                        const string closeHeaderSql = @"
                            UPDATE Pur_Ord_Mst 
                            SET ClosePO = -1 
                            WHERE PO_No = @PoNo 
                              AND PO_No IN (
                                  SELECT DISTINCT PO_No 
                                  FROM Pur_Ordr_Det AS a 
                                  GROUP BY PO_No 
                                  HAVING COUNT(PO_No) <= (SELECT COUNT(*) FROM Pur_Ordr_Det WHERE PO_No = a.PO_No AND closepo <> 0)
                              );";
                        await conn.ExecuteAsync(closeHeaderSql, new { PoNo = poNo }, tx);
                    }
                    else if (actionType.Equals("unclose", StringComparison.OrdinalIgnoreCase))
                    {
                        const string uncloseHeaderSql = @"
                            UPDATE Pur_Ord_Mst 
                            SET ClosePO = 0 
                            WHERE PO_No = @PoNo;";
                        await conn.ExecuteAsync(uncloseHeaderSql, new { PoNo = poNo }, tx);
                    }
                }

                tx.Commit();
                return affectedLines;
            }
            catch (Exception ex)
            {
                tx.Rollback();
                _logger.LogError(ex, "Transaction rolled back while executing status action '{Action}' on POs", request.ActionType);
                throw;
            }
        }
    }
}
