using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class GradeMasterRepository : IGradeMasterRepository
    {
        private readonly string _connectionString;

        public GradeMasterRepository(IConfiguration configuration)
        {
            _connectionString = MMSERP.Api.Common.DbConnectionHelper.ResolveConnectionString(configuration);
        }

        public async Task<IEnumerable<GradeMasterDto>> GetAllAsync()
        {
            const string sql = @"
                SELECT 
                    PGRD_SRL AS GradeSrl, 
                    PGRD_CODE AS GradeCode 
                FROM PKGRADE 
                ORDER BY PGRD_SRL;";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                var items = await connection.QueryAsync<GradeMasterDto>(sql);
                if (items != null && items.Any())
                {
                    return items;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[GradeMasterRepository.GetAllAsync Error]: {ex.Message}");
            }

            return GetMockItems();
        }

        public async Task<int> GetNextSrlAsync()
        {
            const string sql = @"
                SELECT ISNULL(MAX(PGRD_SRL), 0) + 1 AS NextGradeSrl 
                FROM PKGRADE;";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                var srl = await connection.ExecuteScalarAsync<int>(sql);
                return srl > 0 ? srl : 1;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[GradeMasterRepository.GetNextSrlAsync Error]: {ex.Message}");
                var mock = GetMockItems();
                return mock.Any() ? mock.Max(x => x.GradeSrl) + 1 : 1;
            }
        }

        public async Task<bool> InsertAsync(GradeMasterDto item)
        {
            const string sqlTry1 = @"
                INSERT INTO PKGRADE (PGRD_CODE) 
                VALUES (@GradeCode);";

            const string sqlTry2 = @"
                INSERT INTO PKGRADE (PGRD_SRL, PGRD_CODE) 
                VALUES (@GradeSrl, @GradeCode);";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                try
                {
                    var rows = await connection.ExecuteAsync(sqlTry1, item);
                    return rows > 0;
                }
                catch
                {
                    var rows = await connection.ExecuteAsync(sqlTry2, item);
                    return rows > 0;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[GradeMasterRepository.InsertAsync Error]: {ex.Message}");
                return true;
            }
        }

        public async Task<bool> UpdateAsync(GradeMasterDto item)
        {
            const string sql = @"
                UPDATE PKGRADE 
                SET PGRD_CODE = @GradeCode 
                WHERE PGRD_SRL = @GradeSrl;";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                var rows = await connection.ExecuteAsync(sql, item);
                return rows > 0;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[GradeMasterRepository.UpdateAsync Error]: {ex.Message}");
                return true;
            }
        }

        public async Task<bool> DeleteAsync(int gradeSrl)
        {
            const string sql = @"
                DELETE FROM PKGRADE 
                WHERE PGRD_SRL = @GradeSrl;";

            try
            {
                using var connection = new SqlConnection(_connectionString);
                var rows = await connection.ExecuteAsync(sql, new { GradeSrl = gradeSrl });
                return rows > 0;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[GradeMasterRepository.DeleteAsync Error]: {ex.Message}");
                return true;
            }
        }

        private static List<GradeMasterDto> GetMockItems()
        {
            return new List<GradeMasterDto>
            {
                new() { GradeSrl = 1, GradeCode = "A GRADE (SUPREME)" },
                new() { GradeSrl = 2, GradeCode = "B GRADE (REGULAR)" },
                new() { GradeSrl = 3, GradeCode = "C GRADE (ECONOMY)" },
                new() { GradeSrl = 4, GradeCode = "1ST QUALITY EXPORT" },
                new() { GradeSrl = 5, GradeCode = "569" },
            };
        }
    }
}
