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
    // ============================================================================
    // REFERENCE SCHEMA FOR LEGACY ENTERPRISE TABLES: BOMMst, BOMSubMst, DAYBOOK
    // (Do not execute DDL at runtime. These tables are pre-existing and populated.)
    //
    // 1. BOMMst:
    //    BOMID VARCHAR(50) NOT NULL PRIMARY KEY
    //    BOMCode INT NOT NULL DEFAULT 1
    //    BOM_PicPath VARCHAR(255) NULL
    //    BOM_Margin DECIMAL(18,2) NULL DEFAULT 0
    //    Bom_JobRt DECIMAL(18,2) NULL DEFAULT 0
    //    BOM_Cost DECIMAL(18,2) NULL DEFAULT 0
    //    BOM_Rs DECIMAL(18,2) NULL DEFAULT 0
    //    BOM_US DECIMAL(18,2) NULL DEFAULT 0
    //    BOM_DEPCODE INT NOT NULL
    //    BOM_STRCODE INT NOT NULL
    //    I_Code VARCHAR(100) NOT NULL
    //    DESCRIPTION VARCHAR(255) NOT NULL
    //    Qty DECIMAL(18,4) NOT NULL DEFAULT 1
    //    Unit_Code INT NOT NULL
    //    Purpose VARCHAR(50) NOT NULL DEFAULT 'Costing'
    //    Status VARCHAR(20) NOT NULL DEFAULT 'OPEN'
    //    TypeID INT NULL DEFAULT 0
    //    Bom_Type VARCHAR(20) NOT NULL DEFAULT 'JOB'
    //    Bom_Date DATETIME NOT NULL DEFAULT GETDATE()
    //    Bom_Season VARCHAR(50) NULL
    //    Bom_FabCont VARCHAR(100) NULL
    //    Bom_PCode VARCHAR(50) NULL
    //    Bom_PO VARCHAR(100) NULL
    //    Bom_SOCode VARCHAR(50) NULL
    //    Bom_Brand VARCHAR(50) NULL
    //    Bom_Size VARCHAR(50) NULL
    //    Bom_Designer VARCHAR(50) NULL
    //    Bom_Color VARCHAR(50) NULL
    //    BOM_LOC VARCHAR(50) NULL DEFAULT 'LWHL26_SQL'
    //    BOM_EDate DATETIME NOT NULL DEFAULT GETDATE()
    //    BOM_UsrName VARCHAR(50) NOT NULL DEFAULT 'ADMIN'
    //    BOM_EMode VARCHAR(20) NOT NULL DEFAULT 'New'
    //    BOM_Freight DECIMAL(18,2) NULL DEFAULT 0
    //    BOM_OverAll DECIMAL(18,2) NULL DEFAULT 0
    //    BOM_SecPer DECIMAL(18,2) NULL DEFAULT 0
    //    BOM_RejPer DECIMAL(18,2) NULL DEFAULT 0
    //    Bom_MCNo VARCHAR(50) NULL
    //    BOM_USED BIT NULL DEFAULT 0
    //
    // 2. BOMSubMst:
    //    BOMSID VARCHAR(50) NOT NULL
    //    BOMSCode VARCHAR(50) NOT NULL
    //    BOMCode INT NOT NULL DEFAULT 0
    //    It_GroupCD INT NOT NULL DEFAULT 0
    //    I_Code VARCHAR(100) NOT NULL
    //    DESCRIPTION VARCHAR(255) NOT NULL
    //    BOM_Width DECIMAL(18,2) NULL DEFAULT 0
    //    BOM_GSM DECIMAL(18,2) NULL DEFAULT 0
    //    Qty DECIMAL(18,4) NOT NULL DEFAULT 1
    //    Unit_Code INT NOT NULL DEFAULT 0
    //    Bom_TotQty DECIMAL(18,4) NOT NULL DEFAULT 1
    //    Bom_Cons DECIMAL(18,4) NOT NULL DEFAULT 1
    //    Bom_Extra DECIMAL(18,2) NOT NULL DEFAULT 0
    //    Bom_TolQty DECIMAL(18,4) NOT NULL DEFAULT 0
    //    Bom_Rate DECIMAL(18,2) NULL DEFAULT 0
    //    Bom_RateUnit VARCHAR(20) NULL
    //    Bom_Amount DECIMAL(18,2) NULL DEFAULT 0
    //    Bom_Remarks VARCHAR(500) NULL
    //    Bom_FabPhoto VARCHAR(255) NULL
    //    bom_shade VARCHAR(50) NULL
    //    bom_sizedet VARCHAR(50) NULL
    //    bom_DesNo VARCHAR(50) NULL
    //    CONSTRAINT PK_BOMSubMst PRIMARY KEY (BOMSID, BOMSCode)
    //
    // 3. DAYBOOK:
    //    DB_ID INT IDENTITY(1,1) PRIMARY KEY
    //    DB_DATE DATETIME NOT NULL DEFAULT GETDATE()
    //    DB_TYPE VARCHAR(50) NOT NULL
    //    DB_PNAME VARCHAR(100) NULL
    //    DB_AMT DECIMAL(18,2) NULL DEFAULT 0
    //    DB_REFNO VARCHAR(50) NOT NULL
    //    DB_ACTION VARCHAR(50) NOT NULL
    //    DB_TYP VARCHAR(50) NULL
    //    DB_DR VARCHAR(10) NULL
    //    DB_COMPNAME VARCHAR(100) NULL
    // ============================================================================

    public class BomRepository : IBomRepository
    {
        private readonly string _connectionString;

        public BomRepository(IConfiguration configuration)
        {
            _connectionString = DbConnectionHelper.ResolveConnectionString(configuration);
        }

        private IDbConnection CreateConnection() => new SqlConnection(_connectionString);

        private static async Task<string> GenerateNextBomIdInternalAsync(IDbConnection connection, IDbTransaction? transaction, string mode)
        {
            var isJob = string.Equals(mode, "JOB", StringComparison.OrdinalIgnoreCase);
            var prefix = isJob ? "BMCJ" : "BMCC";
            var now = DateTime.Now;
            var fyStart = (now.Month >= 4) ? new DateTime(now.Year, 4, 1) : new DateTime(now.Year - 1, 4, 1);
            var fyEnd = (now.Month >= 4) ? new DateTime(now.Year + 1, 3, 31) : new DateTime(now.Year, 3, 31);
            var fyYear = (now.Month >= 4) ? (now.Year % 100) + 1 : (now.Year % 100);
            var fySuffix = fyYear.ToString("D2");

            const string sql = @"
                SELECT ISNULL(MAX(TRY_CAST(SUBSTRING(BOMID, 6, 6) AS INT)), 0) + 1
                FROM BOMMst WITH (UPDLOCK, HOLDLOCK)
                WHERE LEFT(BOMID, 4) = @Prefix 
                  AND (Purpose = 'Costing' OR Purpose = 'COSTING')
                  AND Bom_Date >= @FyStart AND Bom_Date <= @FyEnd;";

            var nextSeq = await connection.ExecuteScalarAsync<int>(sql, new { Prefix = prefix, FyStart = fyStart, FyEnd = fyEnd }, transaction);
            return $"{prefix}/{nextSeq:D6}/{fySuffix}";
        }

        public async Task<string> GetNextBomIdAsync(string mode)
        {
            using var connection = CreateConnection();
            if (connection.State != ConnectionState.Open) connection.Open();
            using var transaction = connection.BeginTransaction();
            try
            {
                var nextId = await GenerateNextBomIdInternalAsync(connection, transaction, mode);
                transaction.Commit();
                return nextId;
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }

        public async Task<IEnumerable<BomRecordSummaryDto>> GetAllSummariesAsync(string? mode = null, string? query = null)
        {
            using var connection = CreateConnection();

            var cleanQ = query?.Trim() ?? string.Empty;
            var cleanMode = mode?.Trim().ToUpper() ?? string.Empty;

            const string sql = @"
                SELECT 
                    b.BOMID AS BomId,
                    CAST(b.BOMCode AS VARCHAR(50)) AS BomCode,
                    b.BOM_DEPCODE AS DepCode,
                    ISNULL(d.LAB_NAME, 'PRODUCTION') AS DepName,
                    b.BOM_STRCODE AS StrCode,
                    ISNULL(s.STR_NAME, 'MAIN STORE') AS StrName,
                    b.I_Code AS ICode,
                    b.DESCRIPTION AS Description,
                    CAST(b.Qty AS FLOAT) AS Qty,
                    b.Unit_Code AS UnitCode,
                    ISNULL(u.Unit_Name, 'PCS') AS UnitName,
                    b.Status AS Status,
                    b.Bom_Type AS BomType,
                    b.Bom_Date AS BomDate,
                    ISNULL(b.Bom_PO, '') AS BomPo,
                    ISNULL(sub.SubCount, 0) AS SubItemCount,
                    CAST(ISNULL(sub.TotalCons, 0.0) AS FLOAT) AS TotalConsumption,
                    CAST(ISNULL(sub.TotalNet, 0.0) AS FLOAT) AS TotalNetQty
                FROM BOMMst b
                LEFT JOIN STOREMST s ON b.BOM_STRCODE = s.STR_CODE
                LEFT JOIN LABOURMST d ON b.BOM_DEPCODE = d.LAB_CODE
                LEFT JOIN UNITMST u ON b.Unit_Code = u.Unit_Code
                LEFT JOIN (
                    SELECT 
                        BOMSID, 
                        COUNT(*) AS SubCount, 
                        SUM(Bom_Cons) AS TotalCons, 
                        SUM(Bom_TotQty) AS TotalNet
                    FROM BOMSubMst
                    GROUP BY BOMSID
                ) sub ON b.BOMID = sub.BOMSID
                WHERE (@CleanMode = '' OR UPPER(b.Bom_Type) = @CleanMode)
                  AND (@CleanQ = '' OR 
                       b.BOMID LIKE '%' + @CleanQ + '%' OR 
                       b.I_Code LIKE '%' + @CleanQ + '%' OR 
                       b.DESCRIPTION LIKE '%' + @CleanQ + '%' OR 
                       b.Bom_PO LIKE '%' + @CleanQ + '%' OR 
                       s.STR_NAME LIKE '%' + @CleanQ + '%' OR 
                       d.LAB_NAME LIKE '%' + @CleanQ + '%')
                ORDER BY b.Bom_Date DESC, b.BOMID DESC;";

            return await connection.QueryAsync<BomRecordSummaryDto>(sql, new { CleanMode = cleanMode, CleanQ = cleanQ });
        }

        public async Task<BomCompleteRecordDto?> GetByIdAsync(string bomId)
        {
            using var connection = CreateConnection();

            const string sql = @"
                SELECT 
                    b.BOMID AS BomId,
                    CAST(b.BOMCode AS VARCHAR(50)) AS BomCode,
                    b.BOM_DEPCODE AS DepCode,
                    ISNULL(d.LAB_NAME, 'PRODUCTION') AS DepName,
                    b.BOM_STRCODE AS StrCode,
                    ISNULL(s.STR_NAME, 'MAIN STORE') AS StrName,
                    b.I_Code AS ICode,
                    b.DESCRIPTION AS Description,
                    CAST(b.Qty AS FLOAT) AS Qty,
                    b.Unit_Code AS UnitCode,
                    ISNULL(u.Unit_Name, 'PCS') AS UnitName,
                    b.Purpose AS Purpose,
                    b.Status AS Status,
                    b.Bom_Type AS BomType,
                    b.Bom_Date AS BomDate,
                    ISNULL(b.Bom_PO, '') AS BomPo,
                    ISNULL(b.BOM_LOC, 'LWHL26_SQL') AS BomLoc,
                    ISNULL(b.BOM_UsrName, 'SYSTEM') AS BomUsrName,
                    ISNULL(b.BOM_EMode, 'New') AS BomEMode,
                    b.BOM_EDate AS BomEDate
                FROM BOMMst b
                LEFT JOIN STOREMST s ON b.BOM_STRCODE = s.STR_CODE
                LEFT JOIN LABOURMST d ON b.BOM_DEPCODE = d.LAB_CODE
                LEFT JOIN UNITMST u ON b.Unit_Code = u.Unit_Code
                WHERE b.BOMID = @BomId;

                SELECT 
                    sub.BOMSID AS BomsId,
                    sub.BOMSCode AS BomsCode,
                    ISNULL(CAST(sub.BOMCode AS VARCHAR(50)), '') AS BomCode,
                    ISNULL(sub.It_GroupCD, 0) AS ItGroupCd,
                    sub.I_Code AS ICode,
                    sub.DESCRIPTION AS Description,
                    ISNULL(w.WIP_NAME, 'RAW MATERIAL') AS MaterialType,
                    ISNULL(TRY_CAST(sub.Qty AS FLOAT), 0.0) AS Qty,
                    ISNULL(sub.Unit_Code, 0) AS UnitCode,
                    ISNULL(u.Unit_Name, 'PCS') AS UnitName,
                    ISNULL(TRY_CAST(sub.BOM_Width AS FLOAT), 0.0) AS Sqm,
                    ISNULL(TRY_CAST(sub.Bom_Cons AS FLOAT), 0.0) AS BomCons,
                    ISNULL(TRY_CAST(sub.Bom_Extra AS FLOAT), 0.0) AS BomExtra,
                    ISNULL(TRY_CAST(sub.Bom_TolQty AS FLOAT), 0.0) AS BomTolQty,
                    ISNULL(TRY_CAST(sub.Bom_TotQty AS FLOAT), 0.0) AS BomTotQty,
                    CAST(ISNULL(s1.SIM_CONVQTY, 1.0) AS FLOAT) AS ConvQty,
                    ISNULL(TRY_CAST(sub.Bom_Rate AS FLOAT), 0.0) AS BomRate,
                    ISNULL(CAST(sub.Bom_RateUnit AS VARCHAR(50)), '') AS BomRateUnit,
                    ISNULL(TRY_CAST(sub.Bom_Amount AS FLOAT), 0.0) AS BomAmount,
                    ISNULL(sub.Bom_Remarks, '') AS BomRemarks,
                    ISNULL(TRY_CAST(sub.BOM_GSM AS FLOAT), 0.0) AS BomGsm,
                    ISNULL(sub.Bom_FabPhoto, '') AS BomFabPhoto,
                    ISNULL(sub.bom_shade, '') AS BomShade,
                    ISNULL(sub.bom_sizedet, '') AS BomSizeDet,
                    ISNULL(sub.bom_DesNo, '') AS BomDesNo
                FROM BOMSubMst sub
                LEFT JOIN UNITMST u ON sub.Unit_Code = u.Unit_Code
                LEFT JOIN ITEMMST im ON sub.I_Code = im.I_Code
                LEFT JOIN WIPMST w ON im.I_PREFIX = w.WIP_CODE
                LEFT JOIN SUBITEMMST s1 ON sub.I_Code = s1.SIM_CODE
                WHERE sub.BOMSID = @BomId
                ORDER BY TRY_CAST(sub.BOMSCode AS INT), sub.BOMSCode ASC;";

            using var multi = await connection.QueryMultipleAsync(sql, new { BomId = bomId });
            var header = await multi.ReadFirstOrDefaultAsync<BomHeaderDto>();
            if (header == null) return null;

            var items = (await multi.ReadAsync<BomSubItemDto>()).ToList();
            return new BomCompleteRecordDto
            {
                Header = header,
                Items = items,
            };
        }

        public async Task<string> SaveBomAsync(BomCompleteRecordDto record, string user = "SYSTEM")
        {
            using var connection = CreateConnection();
            if (connection.State != ConnectionState.Open) connection.Open();

            // Single ACID SQL Transaction
            using var transaction = connection.BeginTransaction();
            try
            {
                var h = record.Header;
                const string checkStatusSql = "SELECT Status FROM BOMMst WITH (UPDLOCK, HOLDLOCK) WHERE RTRIM(LTRIM(BOMID)) = RTRIM(LTRIM(@BomId));";
                var existingStatus = await connection.ExecuteScalarAsync<string>(checkStatusSql, new { h.BomId }, transaction);
                var exists = existingStatus != null;

                if (exists && string.Equals(existingStatus?.Trim(), "APPROVED", StringComparison.OrdinalIgnoreCase))
                {
                    transaction.Rollback();
                    throw new InvalidOperationException("This BOM is approved and cannot be modified. Contact an administrator if changes are required.");
                }

                string finalBomId;
                int bomCodeInt = int.TryParse(h.BomCode, out var parsedBc) && parsedBc > 0 ? parsedBc : 1;
                if (!exists)
                {
                    // Concurrency-safe ID generation within the insert transaction
                    finalBomId = await GenerateNextBomIdInternalAsync(connection, transaction, h.BomType);
                    h.BomId = finalBomId;

                    // INSERT INTO BOMMst
                    const string insertMasterSql = @"
                        INSERT INTO BOMMst (
                            BOMID, BOMCode, BOM_DEPCODE, BOM_STRCODE, I_Code, DESCRIPTION, 
                            Qty, Unit_Code, Purpose, Status, Bom_Type, Bom_Date, Bom_PO, 
                            BOM_LOC, BOM_UsrName, BOM_EMode, BOM_EDate
                        ) VALUES (
                            @BomId, @BomCode, @DepCode, @StrCode, @ICode, @Description, 
                            @Qty, @UnitCode, @Purpose, @Status, @BomType, @BomDate, @BomPo, 
                            @BomLoc, @BomUsrName, @BomEMode, @BomEDate
                        );";

                    await connection.ExecuteAsync(insertMasterSql, new
                    {
                        BomId = finalBomId,
                        BomCode = bomCodeInt,
                        h.DepCode,
                        h.StrCode,
                        h.ICode,
                        h.Description,
                        h.Qty,
                        h.UnitCode,
                        h.Purpose,
                        h.Status,
                        h.BomType,
                        h.BomDate,
                        h.BomPo,
                        h.BomLoc,
                        BomUsrName = user,
                        BomEMode = "New",
                        BomEDate = DateTime.UtcNow,
                    }, transaction);
                }
                else
                {
                    finalBomId = h.BomId;

                    // UPDATE BOMMst
                    const string updateMasterSql = @"
                        UPDATE BOMMst SET
                            BOM_DEPCODE = @DepCode,
                            BOM_STRCODE = @StrCode,
                            I_Code = @ICode,
                            DESCRIPTION = @Description,
                            Qty = @Qty,
                            Unit_Code = @UnitCode,
                            Purpose = @Purpose,
                            Status = @Status,
                            Bom_Type = @BomType,
                            Bom_Date = @BomDate,
                            Bom_PO = @BomPo,
                            BOM_UsrName = @BomUsrName,
                            BOM_EMode = 'Update',
                            BOM_EDate = @BomEDate
                        WHERE BOMID = @BomId;";

                    await connection.ExecuteAsync(updateMasterSql, new
                    {
                        h.DepCode,
                        h.StrCode,
                        h.ICode,
                        h.Description,
                        h.Qty,
                        h.UnitCode,
                        h.Purpose,
                        h.Status,
                        h.BomType,
                        h.BomDate,
                        h.BomPo,
                        BomUsrName = user,
                        BomEDate = DateTime.UtcNow,
                        BomId = finalBomId,
                    }, transaction);
                }

                // Delete old detail records for this BOMID
                const string deleteSubSql = "DELETE FROM BOMSubMst WHERE RTRIM(LTRIM(BOMSID)) = RTRIM(LTRIM(@BomId));";
                await connection.ExecuteAsync(deleteSubSql, new { BomId = finalBomId }, transaction);

                // Re-insert detail records
                if (record.Items != null && record.Items.Count > 0)
                {
                    const string insertSubSql = @"
                        INSERT INTO BOMSubMst (
                            BOMSID, BOMSCode, BOMCode, It_GroupCD, I_Code, DESCRIPTION, 
                            BOM_Width, BOM_GSM, Qty, Unit_Code, Bom_TotQty, Bom_Cons, Bom_Extra, 
                            Bom_TolQty, Bom_Rate, Bom_RateUnit, Bom_Amount, Bom_Remarks,
                            Bom_FabPhoto, bom_shade, bom_sizedet, bom_DesNo
                        ) VALUES (
                            @BomsId, @BomsCode, @BomCode, @ItGroupCd, @ICode, @Description, 
                            @Sqm, @BomGsm, @Qty, @UnitCode, @BomTotQty, @BomCons, @BomExtra, 
                            @BomTolQty, @BomRate, @BomRateUnit, @BomAmount, @BomRemarks,
                            @BomFabPhoto, @BomShade, @BomSizeDet, @BomDesNo
                        );";

                    foreach (var item in record.Items)
                    {
                        item.BomsId = finalBomId;
                        await connection.ExecuteAsync(insertSubSql, new
                        {
                            BomsId = finalBomId,
                            BomsCode = !string.IsNullOrWhiteSpace(item.BomsCode) ? item.BomsCode : "1",
                            BomCode = bomCodeInt,
                            item.ItGroupCd,
                            ICode = item.ICode ?? "",
                            Description = item.Description ?? "",
                            item.Sqm,
                            item.BomGsm,
                            item.Qty,
                            item.UnitCode,
                            item.BomTotQty,
                            item.BomCons,
                            item.BomExtra,
                            item.BomTolQty,
                            item.BomRate,
                            BomRateUnit = item.BomRateUnit ?? "",
                            item.BomAmount,
                            BomRemarks = item.BomRemarks ?? "",
                            BomFabPhoto = item.BomFabPhoto ?? "",
                            BomShade = item.BomShade ?? "",
                            BomSizeDet = item.BomSizeDet ?? "",
                            BomDesNo = !string.IsNullOrWhiteSpace(item.BomDesNo)
                                ? item.BomDesNo
                                : (!string.IsNullOrWhiteSpace(h.ICode) ? h.ICode : ""),
                        }, transaction);
                    }
                }

                // Insert into DAYBOOK audit trail (matches enterprise trace schema)
                const string daybookSql = @"
                    INSERT INTO DAYBOOK (
                        DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME
                    ) VALUES (
                        GETDATE(), @User, '', @Qty, @BomId, @Action, 'BOM', '1', 'NEWTECHINFOSOL'
                    );";

                await connection.ExecuteAsync(daybookSql, new
                {
                    User = !string.IsNullOrWhiteSpace(user) ? user : "ADMIN",
                    Qty = h.Qty,
                    BomId = finalBomId,
                    Action = exists ? "UPDATE" : "NEW",
                }, transaction);

                transaction.Commit();
                return finalBomId;
            }
            catch (Exception)
            {
                transaction.Rollback();
                throw;
            }
        }

        public async Task<bool> DeleteBomAsync(string bomId, string user = "SYSTEM")
        {
            using var connection = CreateConnection();
            if (connection.State != ConnectionState.Open) connection.Open();

            using var transaction = connection.BeginTransaction();
            try
            {
                const string checkStatusSql = "SELECT Status FROM BOMMst WITH (UPDLOCK, HOLDLOCK) WHERE RTRIM(LTRIM(BOMID)) = RTRIM(LTRIM(@BomId));";
                var status = await connection.ExecuteScalarAsync<string>(checkStatusSql, new { BomId = bomId }, transaction);
                if (status == null)
                {
                    transaction.Rollback();
                    return false;
                }

                if (string.Equals(status.Trim(), "APPROVED", StringComparison.OrdinalIgnoreCase))
                {
                    transaction.Rollback();
                    throw new InvalidOperationException("This BOM is approved and cannot be deleted. Contact an administrator if changes are required.");
                }

                // Delete detail items
                const string deleteSubSql = "DELETE FROM BOMSubMst WHERE RTRIM(LTRIM(BOMSID)) = RTRIM(LTRIM(@BomId));";
                await connection.ExecuteAsync(deleteSubSql, new { BomId = bomId }, transaction);

                // Delete master
                const string deleteMasterSql = "DELETE FROM BOMMst WHERE RTRIM(LTRIM(BOMID)) = RTRIM(LTRIM(@BomId));";
                var rows = await connection.ExecuteAsync(deleteMasterSql, new { BomId = bomId }, transaction);

                // Audit log (matches enterprise trace schema)
                const string daybookSql = @"
                    INSERT INTO DAYBOOK (
                        DB_DATE, DB_TYPE, DB_PNAME, DB_AMT, DB_REFNO, DB_ACTION, DB_TYP, DB_DR, DB_COMPNAME
                    ) VALUES (
                        GETDATE(), @User, '', 0, @BomId, 'DELETE', 'BOM', '1', 'NEWTECHINFOSOL'
                    );";

                await connection.ExecuteAsync(daybookSql, new
                {
                    User = !string.IsNullOrWhiteSpace(user) ? user : "ADMIN",
                    BomId = bomId,
                }, transaction);

                transaction.Commit();
                return rows > 0;
            }
            catch (Exception)
            {
                transaction.Rollback();
                throw;
            }
        }

        public async Task<IEnumerable<BomStoreLookupDto>> GetStoresAsync()
        {
            using var connection = CreateConnection();
            const string checkSql = "SELECT COUNT(1) FROM sys.tables WHERE name = 'STOREMST';";
            if (await connection.ExecuteScalarAsync<int>(checkSql) == 0)
            {
                throw new InvalidOperationException("Required table STOREMST was not found in the connected database.");
            }

            const string sql = @"SELECT STR_NAME AS StrName, STR_CODE AS StrCode FROM STOREMST WHERE STR_NAME <> '' ORDER BY STR_NAME;";
            return await connection.QueryAsync<BomStoreLookupDto>(sql);
        }

        public async Task<IEnumerable<BomDepartmentLookupDto>> GetDepartmentsAsync()
        {
            using var connection = CreateConnection();
            const string checkSql = "SELECT COUNT(1) FROM sys.tables WHERE name = 'LABOURMST';";
            if (await connection.ExecuteScalarAsync<int>(checkSql) == 0)
            {
                throw new InvalidOperationException("Required table LABOURMST was not found in the connected database.");
            }

            const string sql = @"SELECT LAB_NAME AS LabName, LAB_CODE AS LabCode FROM LABOURMST WHERE (LAB_STATUS = '' OR LAB_STATUS IS NULL OR LAB_STATUS = 'YES') ORDER BY LAB_NAME;";
            return await connection.QueryAsync<BomDepartmentLookupDto>(sql);
        }

        public async Task<IEnumerable<BomUnitLookupDto>> GetUnitsAsync()
        {
            using var connection = CreateConnection();
            const string checkSql = "SELECT COUNT(1) FROM sys.tables WHERE name = 'UNITMST';";
            if (await connection.ExecuteScalarAsync<int>(checkSql) == 0)
            {
                throw new InvalidOperationException("Required table UNITMST was not found in the connected database.");
            }

            const string sql = @"SELECT Unit_Code AS UnitCode, Unit_Name AS UnitName FROM UNITMST ORDER BY Unit_Name;";
            return await connection.QueryAsync<BomUnitLookupDto>(sql);
        }

        public async Task<IEnumerable<FinishedGoodLookupDto>> GetFinishedGoodsAsync(string skuCross = "", string query = "")
        {
            using var connection = CreateConnection();
            const string checkSql = "SELECT COUNT(1) FROM sys.tables WHERE name = 'ITEMMST';";
            if (await connection.ExecuteScalarAsync<int>(checkSql) == 0)
            {
                throw new InvalidOperationException("Required table ITEMMST was not found in the connected database.");
            }

            var targetCross = (skuCross.Equals("REGULAR", StringComparison.OrdinalIgnoreCase) || skuCross.Equals("R", StringComparison.OrdinalIgnoreCase)) ? "R" : "J";
            var cleanQ = query?.Trim() ?? string.Empty;

            const string sql = @"
                SELECT TOP 150 
                    IM.I_CODE AS ICode,
                    ISNULL(IM.I_NAME1, IM.I_CODE) AS ItName,
                    ISNULL(UM.UNIT_NAME, 'PCS') AS UnitName,
                    ISNULL(UM.UNIT_CODE, 22) AS UnitCode,
                    CASE WHEN (IM.I_BLOCK = 0 OR IM.I_BLOCK IS NULL) THEN 'OPEN' ELSE 'BLOCKED' END AS Status,
                    @TargetCross AS SkuCross,
                    ISNULL(CT.CAT_CODE, 0) AS CatCode
                FROM ITEMMST AS IM 
                LEFT OUTER JOIN UNITMST AS UM ON IM.I_UOM = UM.UNIT_CODE 
                LEFT JOIN CATEGORYMST AS CT ON IM.I_CID = CT.CAT_CODE 
                LEFT JOIN WIPMST AS WM ON IM.I_PREFIX = WM.WIP_CODE 
                WHERE IM.I_HSN <> '' 
                  AND (IM.I_CODE + ' ' + ISNULL(IM.I_NAME1, '') LIKE '%' + @CleanQ + '%') 
                  AND (WM.WIP_NAME = 'FINISH' OR WM.WIP_NAME IS NULL)
                  AND (
                      EXISTS (SELECT 1 FROM SKUMST WHERE SKU_CODE = IM.I_CODE AND SKU_CROSS = @TargetCross)
                      OR NOT EXISTS (SELECT 1 FROM SKUMST)
                  )
                ORDER BY IM.I_NAME1;";

            return await connection.QueryAsync<FinishedGoodLookupDto>(sql, new { TargetCross = targetCross, CleanQ = cleanQ });
        }

        public async Task<IEnumerable<ComponentLookupDto>> GetComponentsAsync(string parentCode = "", string query = "")
        {
            using var connection = CreateConnection();
            const string checkSql = "SELECT COUNT(1) FROM sys.tables WHERE name = 'ITEMMST';";
            if (await connection.ExecuteScalarAsync<int>(checkSql) == 0)
            {
                throw new InvalidOperationException("Required table ITEMMST was not found in the connected database.");
            }

            var pCode = parentCode?.Trim() ?? string.Empty;
            var cleanQ = query?.Trim() ?? string.Empty;

            const string sql = @"
                SELECT TOP 150 
                    IM.I_CODE AS ICode,
                    ISNULL(IM.I_NAME1, IM.I_CODE) AS ItName,
                    ISNULL(UM.UNIT_CODE, 24) AS UnitCode,
                    ISNULL(UM.UNIT_NAME, 'MTR') AS UnitName,
                    ISNULL(CM.CAT_CODE, 0) AS CatCode,
                    ISNULL(CM.CAT_NAME, 'RAW MATERIAL') AS CatName,
                    ISNULL(WM.WIP_NAME, 'RAW MATERIAL') AS MaterialType,
                    CASE WHEN J.UNIT_CODE IS NULL OR J.UNIT_CODE = 0 THEN ISNULL(UM.UNIT_CODE, 24) ELSE J.UNIT_CODE END AS SecUcode,
                    CASE WHEN J.UNIT_CODE IS NULL OR J.UNIT_CODE = 0 THEN ISNULL(UM.UNIT_NAME, 'MTR') ELSE J.UNIT_NAME END AS SecUnit,
                    ISNULL(IM.I_DISPNM, '') AS PrintCode,
                    CAST(ISNULL(S1.SIM_CONVQTY, 1.0) AS FLOAT) AS ConvQty
                FROM ITEMMST AS IM 
                LEFT OUTER JOIN UNITMST AS UM ON UM.UNIT_CODE = IM.I_UOM 
                LEFT JOIN CATEGORYMST AS CM ON IM.I_CID = CM.CAT_CODE 
                LEFT JOIN WIPMST AS WM ON IM.I_PREFIX = WM.WIP_CODE 
                LEFT JOIN SUBITEMMST AS S1 ON IM.I_CODE = S1.SIM_CODE 
                LEFT JOIN UNITMST AS J ON S1.SIM_SECUNIT = J.UNIT_CODE 
                LEFT JOIN SKUMST AS K ON IM.I_CODE = K.SKU_CODE 
                WHERE IM.I_HSN <> '' 
                  AND (IM.I_BLOCK IS NULL OR IM.I_BLOCK = 0) 
                  AND (@PCode = '' OR IM.I_CODE <> @PCode)
                  AND (IM.I_CODE + ' ' + ISNULL(IM.I_NAME1, '') LIKE '%' + @CleanQ + '%') 
                ORDER BY IM.I_NAME1;
            ";

            return await connection.QueryAsync<ComponentLookupDto>(sql, new { PCode = pCode, CleanQ = cleanQ });
        }
    }
}
