using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class ProjectMasterRepository : IProjectMasterRepository
    {
        private readonly string _connectionString;

        public ProjectMasterRepository(IConfiguration configuration)
        {
            _connectionString = Environment.GetEnvironmentVariable("CONNECTION_STRING")
                ?? configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
        }

        public async Task<IEnumerable<ProjectMasterDto>> GetAllAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    PRJ_CODE AS PrjCode, 
                    PRJ_NAME AS PrjName 
                FROM PROJECTMST 
                ORDER BY PRJ_CODE ASC;";
            return await connection.QueryAsync<ProjectMasterDto>(sql);
        }

        public async Task<int> GetNextCodeAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "SELECT ISNULL(MAX(PRJ_CODE), 0) + 1 FROM PROJECTMST;";
            return await connection.ExecuteScalarAsync<int>(sql);
        }

        public async Task<bool> CreateAsync(ProjectMasterDto dto)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                INSERT INTO PROJECTMST (PRJ_CODE, PRJ_NAME) 
                VALUES (@PrjCode, @PrjName);";
            var rows = await connection.ExecuteAsync(sql, new { dto.PrjCode, dto.PrjName });
            return rows > 0;
        }

        public async Task<bool> UpdateAsync(ProjectMasterDto dto)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                UPDATE PROJECTMST 
                SET PRJ_NAME = @PrjName 
                WHERE PRJ_CODE = @PrjCode;";
            var rows = await connection.ExecuteAsync(sql, new { dto.PrjName, dto.PrjCode });
            return rows > 0;
        }

        public async Task<bool> DeleteAsync(int code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "DELETE FROM PROJECTMST WHERE PRJ_CODE = @PrjCode;";
            var rows = await connection.ExecuteAsync(sql, new { PrjCode = code });
            return rows > 0;
        }
    }
}
