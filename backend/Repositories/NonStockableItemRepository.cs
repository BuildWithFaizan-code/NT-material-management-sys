using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class NonStockableItemRepository : INonStockableItemRepository
    {
        private readonly string _connectionString;

        public NonStockableItemRepository(IConfiguration configuration)
        {
            _connectionString = Environment.GetEnvironmentVariable("CONNECTION_STRING")
                ?? configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
        }

        public async Task<NonStockableDropdownsDto> GetDropdownsAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string unitsSql = "SELECT UNIT_NAME AS UnitName, UNIT_CODE AS UnitCode FROM UNITMST ORDER BY UNIT_NAME;";
            const string taxSql = "SELECT TAX_NAME AS TaxName, TAX_CODE AS TaxCode FROM TAX_SLAB_MST ORDER BY TAX_NAME;";

            IEnumerable<UnitOptionDto> dbUnits = new List<UnitOptionDto>();
            IEnumerable<TaxSlabOptionDto> dbTaxSlabs = new List<TaxSlabOptionDto>();

            try
            {
                var unitsTask = connection.QueryAsync<UnitOptionDto>(unitsSql);
                var taxTask = connection.QueryAsync<TaxSlabOptionDto>(taxSql);
                await Task.WhenAll(unitsTask, taxTask);
                dbUnits = await unitsTask;
                dbTaxSlabs = await taxTask;
            }
            catch
            {
                // Fallback to empty if DB query fails
            }

            var defaultUnits = new List<string>
            {
                "BAG", "BAL", "BDL", "BKL", "BOOK", "BOU", "BOX", "BRASS", "BTL", "BUN",
                "CAN", "CBM", "CCM", "CMS", "COPS", "CTN", "DOZ", "DRM", "FT", "GGK",
                "GMS", "GRS", "GYD", "HOUR", "KGS", "KLR", "KME", "KWH", "LTR", "MTR",
                "NOS", "PAC", "PCS", "PKT", "RIM", "SET", "SHEETS", "SQF"
            };

            var defaultTaxSlabs = new List<(string Name, int Code)>
            {
                ("0%", 0),
                ("3%", 3),
                ("5%", 5),
                ("12%", 12),
                ("18%", 18),
                ("28%", 28)
            };

            var finalUnitsList = dbUnits.ToList();
            int nextUnitCode = finalUnitsList.Any() ? finalUnitsList.Max(u => u.UnitCode) + 1 : 1;

            foreach (var unitName in defaultUnits)
            {
                if (!finalUnitsList.Any(u => string.Equals(u.UnitName?.Trim(), unitName, StringComparison.OrdinalIgnoreCase)))
                {
                    finalUnitsList.Add(new UnitOptionDto { UnitName = unitName, UnitCode = nextUnitCode++ });
                }
            }

            var finalTaxList = dbTaxSlabs.ToList();

            foreach (var (name, code) in defaultTaxSlabs)
            {
                if (!finalTaxList.Any(t => string.Equals(t.TaxName?.Trim(), name, StringComparison.OrdinalIgnoreCase) || t.TaxCode == code))
                {
                    finalTaxList.Add(new TaxSlabOptionDto { TaxName = name, TaxCode = code });
                }
            }

            return new NonStockableDropdownsDto
            {
                Units = finalUnitsList.OrderBy(u => u.UnitName).ToList(),
                TaxSlabs = finalTaxList.OrderBy(t => t.TaxName).ToList()
            };
        }

        public async Task<IEnumerable<UnassignedItemDto>> GetUnassignedItemsAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    IM.I_CODE AS ICode, 
                    ISNULL(IM.I_NAME1, '') AS IName1, 
                    ISNULL(IM.I_SRATE, 0) AS Rate, 
                    ISNULL(CAST(IM.I_UOM AS NVARCHAR(50)), '') AS UnitCode, 
                    ISNULL(IM.I_HSN, '') AS SacCode, 
                    ISNULL(CAST(IM.I_TAXSLAB AS NVARCHAR(50)), '') AS TaxCode 
                FROM ITEMMST AS IM 
                LEFT JOIN NONSTKITM AS NST ON IM.I_CODE = NST.I_CODE 
                WHERE NST.I_CODE IS NULL 
                ORDER BY IM.I_NAME1;";
            return await connection.QueryAsync<UnassignedItemDto>(sql);
        }

        public async Task<IEnumerable<NonStockableItemDto>> GetAllAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    NST.I_Code AS ICode, 
                    ISNULL(NST.I_Name1, '') AS IName1, 
                    ISNULL(NST.Rate, 0) AS Rate, 
                    ISNULL(NST.Unit_Code, 0) AS UnitCode, 
                    ISNULL(UM.UNIT_NAME, '') AS UnitName, 
                    ISNULL(NST.Sac_Code, '') AS SacCode, 
                    ISNULL(NST.Tax_Code, 0) AS TaxCode, 
                    ISNULL(TM.TAX_NAME, '') AS TaxName 
                FROM NONSTKITM AS NST 
                LEFT JOIN UNITMST UM ON NST.Unit_Code = UM.UNIT_CODE 
                LEFT JOIN TAX_SLAB_MST TM ON NST.Tax_Code = TM.TAX_CODE 
                ORDER BY NST.I_Name1;";
            return await connection.QueryAsync<NonStockableItemDto>(sql);
        }

        public async Task<NonStockableItemDto?> GetByCodeAsync(string code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    NST.I_Code AS ICode, 
                    ISNULL(NST.I_Name1, '') AS IName1, 
                    ISNULL(NST.Rate, 0) AS Rate, 
                    ISNULL(NST.Unit_Code, 0) AS UnitCode, 
                    ISNULL(UM.UNIT_NAME, '') AS UnitName, 
                    ISNULL(NST.Sac_Code, '') AS SacCode, 
                    ISNULL(NST.Tax_Code, 0) AS TaxCode, 
                    ISNULL(TM.TAX_NAME, '') AS TaxName 
                FROM NONSTKITM AS NST 
                LEFT JOIN UNITMST UM ON NST.Unit_Code = UM.UNIT_CODE 
                LEFT JOIN TAX_SLAB_MST TM ON NST.Tax_Code = TM.TAX_CODE 
                WHERE NST.I_Code = @ICode;";
            return await connection.QueryFirstOrDefaultAsync<NonStockableItemDto>(sql, new { ICode = code });
        }

        public async Task<bool> SaveAsync(SaveNonStockableItemDto model)
        {
            using var connection = new SqlConnection(_connectionString);
            const string checkSql = "SELECT COUNT(1) FROM NONSTKITM WHERE I_Code = @ICode;";
            var exists = await connection.ExecuteScalarAsync<int>(checkSql, new { ICode = model.ICode }) > 0;

            if (exists)
            {
                const string updateSql = @"
                    UPDATE NONSTKITM 
                    SET I_Name1 = @IName1, 
                        Rate = @Rate, 
                        Unit_Code = @UnitCode, 
                        Sac_Code = @SacCode, 
                        Tax_Code = @TaxCode 
                    WHERE I_Code = @ICode;";
                var rows = await connection.ExecuteAsync(updateSql, model);
                return rows > 0;
            }
            else
            {
                const string insertSql = @"
                    INSERT INTO NONSTKITM (I_Code, I_Name1, Rate, Unit_Code, Sac_Code, Tax_Code) 
                    VALUES (@ICode, @IName1, @Rate, @UnitCode, @SacCode, @TaxCode);";
                var rows = await connection.ExecuteAsync(insertSql, model);
                return rows > 0;
            }
        }

        public async Task<bool> DeleteAsync(string code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "DELETE FROM NONSTKITM WHERE I_Code = @ICode;";
            var rows = await connection.ExecuteAsync(sql, new { ICode = code });
            return rows > 0;
        }
    }
}
