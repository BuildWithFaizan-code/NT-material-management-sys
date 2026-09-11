using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class SubDepartmentMasterRepository : ISubDepartmentMasterRepository
    {
        private readonly string _connectionString;

        public SubDepartmentMasterRepository(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
        }

        public async Task<IEnumerable<SubDepartmentMasterDto>> GetAllAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    SDM_CODE AS SdmCode, 
                    SDM_NAME AS SdmName 
                FROM SUBDEPMST 
                ORDER BY SDM_NAME ASC;";
            return await connection.QueryAsync<SubDepartmentMasterDto>(sql);
        }

        public async Task<SubDepartmentMasterDto?> GetByCodeAsync(int code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    SDM_CODE AS SdmCode, 
                    SDM_NAME AS SdmName 
                FROM SUBDEPMST 
                WHERE SDM_CODE = @Code;";
            return await connection.QueryFirstOrDefaultAsync<SubDepartmentMasterDto>(sql, new { Code = code });
        }

        public async Task<int> GetNextCodeAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "SELECT ISNULL(MAX(SDM_CODE), 0) + 1 FROM SUBDEPMST;";
            return await connection.ExecuteScalarAsync<int>(sql);
        }

        public async Task<bool> CreateAsync(CreateSubDepartmentDto model)
        {
            using var connection = new SqlConnection(_connectionString);
            if (model.SdmCode <= 0)
            {
                model.SdmCode = await GetNextCodeAsync();
            }

            const string sql = @"
                INSERT INTO SUBDEPMST (SDM_CODE, SDM_NAME) 
                VALUES (@SdmCode, @SdmName);";
            var rows = await connection.ExecuteAsync(sql, new { SdmCode = model.SdmCode, SdmName = model.SdmName.Trim().ToUpper() });
            return rows > 0;
        }

        public async Task<bool> UpdateAsync(int code, CreateSubDepartmentDto model)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                UPDATE SUBDEPMST 
                SET SDM_NAME = @SdmName 
                WHERE SDM_CODE = @Code;";
            var rows = await connection.ExecuteAsync(sql, new { Code = code, SdmName = model.SdmName.Trim().ToUpper() });
            return rows > 0;
        }

        public async Task<bool> DeleteAsync(int code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "DELETE FROM SUBDEPMST WHERE SDM_CODE = @Code;";
            var rows = await connection.ExecuteAsync(sql, new { Code = code });
            return rows > 0;
        }
    }
}
