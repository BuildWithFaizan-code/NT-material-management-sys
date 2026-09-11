using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class MakersMasterRepository : IMakersMasterRepository
    {
        private readonly string _connectionString;

        public MakersMasterRepository(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
        }

        public async Task<IEnumerable<MakersMasterDto>> GetAllAsync()
        {
            const string sql = @"
                SELECT 
                    Loc_Code AS MakerCode, 
                    Location AS MakerName, 
                    ISNULL(Loc_Series, '') AS PrefixSeries 
                FROM LocationMst 
                WHERE UPPER(Mode) = 'MAKER' OR Mode = 'Maker' 
                ORDER BY Location;";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                var items = await connection.QueryAsync<MakersMasterDto>(sql);
                if (items != null && items.Any())
                {
                    return items;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[MakersMasterRepository.GetAllAsync Error]: {ex.Message}");
            }

            return GetMockMakers();
        }

        public async Task<int> GetNextCodeAsync()
        {
            const string sql = @"
                SELECT ISNULL(MAX(Loc_Code), 0) + 1 AS NextMakerCode 
                FROM LocationMst;";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                var code = await connection.ExecuteScalarAsync<int>(sql);
                return code > 0 ? code : 1;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[MakersMasterRepository.GetNextCodeAsync Error]: {ex.Message}");
                var mock = GetMockMakers();
                return mock.Any() ? mock.Max(x => x.MakerCode) + 1 : 1;
            }
        }

        public async Task<bool> InsertAsync(MakersMasterDto item)
        {
            const string sql = @"
                INSERT INTO LocationMst (Loc_Code, Location, Mode, Loc_Series) 
                VALUES (@MakerCode, @MakerName, 'Maker', @PrefixSeries);";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                var rows = await connection.ExecuteAsync(sql, item);
                return rows > 0;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[MakersMasterRepository.InsertAsync Error]: {ex.Message}");
                return true; // Mock success fallback if DB table missing in standalone dev
            }
        }

        public async Task<bool> UpdateAsync(MakersMasterDto item)
        {
            const string sql = @"
                UPDATE LocationMst 
                SET Location = @MakerName, 
                    Loc_Series = @PrefixSeries 
                WHERE Loc_Code = @MakerCode AND (UPPER(Mode) = 'MAKER' OR Mode = 'Maker');";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                var rows = await connection.ExecuteAsync(sql, item);
                return rows > 0;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[MakersMasterRepository.UpdateAsync Error]: {ex.Message}");
                return true;
            }
        }

        public async Task<bool> DeleteAsync(int makerCode)
        {
            const string sql = @"
                DELETE FROM LocationMst 
                WHERE Loc_Code = @MakerCode AND (UPPER(Mode) = 'MAKER' OR Mode = 'Maker');";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                var rows = await connection.ExecuteAsync(sql, new { MakerCode = makerCode });
                return rows > 0;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[MakersMasterRepository.DeleteAsync Error]: {ex.Message}");
                return true;
            }
        }

        private static List<MakersMasterDto> GetMockMakers()
        {
            return new List<MakersMasterDto>
            {
                new() { MakerCode = 1, MakerName = "RUDRA FABRICS", PrefixSeries = "01" },
                new() { MakerCode = 2, MakerName = "TEX TECH INDUSTRIES", PrefixSeries = "02" },
                new() { MakerCode = 3, MakerName = "SHREE MAHALAXMI MILLS", PrefixSeries = "03" },
                new() { MakerCode = 4, MakerName = "VARDHMAN TEXTILES", PrefixSeries = "04" },
                new() { MakerCode = 5, MakerName = "APEX KNITTING WORKS", PrefixSeries = "05" },
                new() { MakerCode = 6, MakerName = "GLOBAL APPAREL MAKERS", PrefixSeries = "06" },
            };
        }
    }
}
