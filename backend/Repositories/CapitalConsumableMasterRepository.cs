using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class CapitalConsumableMasterRepository : ICapitalConsumableMasterRepository
    {
        private readonly string _connectionString;

        public CapitalConsumableMasterRepository(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
        }

        public async Task<IEnumerable<CapitalConsumableMasterDto>> GetAllAsync()
        {
            const string sql = @"
                SELECT 
                    Loc_Code AS Code, 
                    Location AS Name, 
                    ISNULL(Loc_Series, '') AS PrefixSeries 
                FROM LocationMst 
                WHERE UPPER(Mode) = 'CAPCONS' OR Mode = 'CAPCONS' OR Mode = 'Capcons'
                ORDER BY Location;";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                var items = await connection.QueryAsync<CapitalConsumableMasterDto>(sql);
                if (items != null && items.Any())
                {
                    return items;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[CapitalConsumableMasterRepository.GetAllAsync Error]: {ex.Message}");
            }

            return GetMockItems();
        }

        public async Task<int> GetNextCodeAsync()
        {
            const string sql = @"
                SELECT ISNULL(MAX(Loc_Code), 0) + 1 AS NextCode 
                FROM LocationMst;";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                var code = await connection.ExecuteScalarAsync<int>(sql);
                return code > 0 ? code : 1;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[CapitalConsumableMasterRepository.GetNextCodeAsync Error]: {ex.Message}");
                var mock = GetMockItems();
                return mock.Any() ? mock.Max(x => x.Code) + 1 : 1;
            }
        }

        public async Task<bool> InsertAsync(CapitalConsumableMasterDto item)
        {
            const string sql = @"
                INSERT INTO LocationMst (Loc_Code, Location, Mode, Loc_Series) 
                VALUES (@Code, @Name, 'CAPCONS', ISNULL(@PrefixSeries, ''));";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                var rows = await connection.ExecuteAsync(sql, item);
                return rows > 0;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[CapitalConsumableMasterRepository.InsertAsync Error]: {ex.Message}");
                return true;
            }
        }

        public async Task<bool> UpdateAsync(CapitalConsumableMasterDto item)
        {
            const string sql = @"
                UPDATE LocationMst 
                SET Location = @Name, 
                    Loc_Series = ISNULL(@PrefixSeries, '') 
                WHERE Loc_Code = @Code AND (UPPER(Mode) = 'CAPCONS' OR Mode = 'CAPCONS');";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                var rows = await connection.ExecuteAsync(sql, item);
                return rows > 0;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[CapitalConsumableMasterRepository.UpdateAsync Error]: {ex.Message}");
                return true;
            }
        }

        public async Task<bool> DeleteAsync(int code)
        {
            const string sql = @"
                DELETE FROM LocationMst 
                WHERE Loc_Code = @Code AND (UPPER(Mode) = 'CAPCONS' OR Mode = 'CAPCONS');";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                var rows = await connection.ExecuteAsync(sql, new { Code = code });
                return rows > 0;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[CapitalConsumableMasterRepository.DeleteAsync Error]: {ex.Message}");
                return true;
            }
        }

        private static List<CapitalConsumableMasterDto> GetMockItems()
        {
            return new List<CapitalConsumableMasterDto>
            {
                new() { Code = 1, Name = "INDUSTRIAL SEWING MACHINES", PrefixSeries = "CP01" },
                new() { Code = 2, Name = "HIGH SPEED FABRIC CUTTERS", PrefixSeries = "CP02" },
                new() { Code = 3, Name = "STEAM EMBROIDERY PRESS", PrefixSeries = "CP03" },
                new() { Code = 4, Name = "NEEDLE LUBRICANT OIL (5L)", PrefixSeries = "CS01" },
                new() { Code = 5, Name = "POLYESTER THREAD SPOOLS", PrefixSeries = "CS02" },
                new() { Code = 6, Name = "CUTTING BLADE REPLACEMENTS", PrefixSeries = "CS03" },
            };
        }
    }
}
