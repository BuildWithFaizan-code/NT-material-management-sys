using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class MainGroupMasterRepository : IMainGroupMasterRepository
    {
        private readonly string _connectionString;

        public MainGroupMasterRepository(IConfiguration configuration)
        {
            _connectionString = MMSERP.Api.Common.DbConnectionHelper.ResolveConnectionString(configuration);
            
            EnsureTableCreated();
        }

        private void EnsureTableCreated()
        {
            try
            {
                using var connection = new SqlConnection(_connectionString);
                const string sql = @"
                    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'WIPMST')
                    BEGIN
                        CREATE TABLE WIPMST (
                            WIP_CODE VARCHAR(50) NOT NULL PRIMARY KEY,
                            WIP_NAME VARCHAR(255) NOT NULL,
                            WIP_MODE VARCHAR(50) NULL DEFAULT 'Regular'
                        );
                    END";
                connection.Execute(sql);
            }
            catch
            {
                // Table setup exception handler
            }
        }

        public async Task<IEnumerable<MainGroupMasterDto>> GetAllAsync(string? searchTerm = null)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    WIP_CODE AS WipCode, 
                    WIP_NAME AS WipName, 
                    ISNULL(WIP_MODE, 'Regular') AS WipMode 
                FROM WIPMST 
                WHERE (@SearchTerm IS NULL OR WIP_NAME LIKE '%' + @SearchTerm + '%' OR WIP_CODE LIKE '%' + @SearchTerm + '%')
                ORDER BY WIP_CODE;";

            return await connection.QueryAsync<MainGroupMasterDto>(sql, new { SearchTerm = searchTerm });
        }

        public async Task<MainGroupMasterDto?> GetByCodeAsync(string wipCode)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    WIP_CODE AS WipCode, 
                    WIP_NAME AS WipName, 
                    ISNULL(WIP_MODE, 'Regular') AS WipMode 
                FROM WIPMST 
                WHERE WIP_CODE = @WipCode;";

            return await connection.QueryFirstOrDefaultAsync<MainGroupMasterDto>(sql, new { WipCode = wipCode });
        }

        public async Task<bool> InsertAsync(MainGroupMasterDto dto)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                INSERT INTO WIPMST (
                    WIP_CODE, 
                    WIP_NAME, 
                    WIP_MODE
                ) VALUES (
                    @WipCode, 
                    @WipName, 
                    @WipMode
                );";

            var rows = await connection.ExecuteAsync(sql, dto);
            return rows > 0;
        }

        public async Task<bool> UpdateAsync(MainGroupMasterDto dto)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                UPDATE WIPMST 
                SET 
                    WIP_NAME = @WipName, 
                    WIP_MODE = @WipMode 
                WHERE WIP_CODE = @WipCode;";

            var rows = await connection.ExecuteAsync(sql, dto);
            return rows > 0;
        }

        public async Task<bool> DeleteAsync(string wipCode)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "DELETE FROM WIPMST WHERE WIP_CODE = @WipCode;";
            var rows = await connection.ExecuteAsync(sql, new { WipCode = wipCode });
            return rows > 0;
        }

        public async Task<string> GetNextCodeAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT ISNULL(MAX(CASE WHEN ISNUMERIC(WIP_CODE) = 1 THEN CAST(WIP_CODE AS BIGINT) ELSE 0 END), 0) + 1 
                FROM WIPMST;";
            var next = await connection.ExecuteScalarAsync<long>(sql);
            return next.ToString();
        }
    }
}
