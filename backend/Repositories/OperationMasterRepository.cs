using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class OperationMasterRepository : IOperationMasterRepository
    {
        private readonly string _connectionString;

        public OperationMasterRepository(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
        }

        public async Task<IEnumerable<OperationMasterDto>> GetAllAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    OM_CODE AS OmCode, 
                    OM_DESC AS OmDesc, 
                    OM_FIXRATE AS OmFixRate,
                    OM_USER AS OmUser,
                    OM_USERDTTIME AS OmUserDtTime
                FROM OPERATION_MST 
                ORDER BY OM_CODE DESC;";
            return await connection.QueryAsync<OperationMasterDto>(sql);
        }

        public async Task<OperationMasterDto?> GetByCodeAsync(int code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    OM_CODE AS OmCode, 
                    OM_DESC AS OmDesc, 
                    OM_FIXRATE AS OmFixRate,
                    OM_USER AS OmUser,
                    OM_USERDTTIME AS OmUserDtTime
                FROM OPERATION_MST 
                WHERE OM_CODE = @Code;";
            return await connection.QueryFirstOrDefaultAsync<OperationMasterDto>(sql, new { Code = code });
        }

        public async Task<int> GetNextCodeAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "SELECT ISNULL(MAX(OM_CODE), 0) + 1 FROM OPERATION_MST;";
            return await connection.ExecuteScalarAsync<int>(sql);
        }

        public async Task<bool> CreateAsync(CreateOperationDto model)
        {
            using var connection = new SqlConnection(_connectionString);
            if (model.OmCode <= 0)
            {
                model.OmCode = await GetNextCodeAsync();
            }

            const string sql = @"
                INSERT INTO OPERATION_MST (OM_CODE, OM_DESC, OM_FIXRATE, OM_USER, OM_USERDTTIME) 
                VALUES (@OmCode, @OmDesc, @OmFixRate, 'ADMIN', GETDATE());";
            var rows = await connection.ExecuteAsync(sql, model);
            return rows > 0;
        }

        public async Task<bool> UpdateAsync(int code, CreateOperationDto model)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                UPDATE OPERATION_MST 
                SET OM_DESC = @OmDesc, 
                    OM_FIXRATE = @OmFixRate,
                    OM_USER = 'ADMIN',
                    OM_USERDTTIME = GETDATE()
                WHERE OM_CODE = @OmCode;";
            var rows = await connection.ExecuteAsync(sql, new { 
                OmCode = code, 
                model.OmDesc, 
                model.OmFixRate 
            });
            return rows > 0;
        }

        public async Task<bool> DeleteAsync(int code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "DELETE FROM OPERATION_MST WHERE OM_CODE = @Code;";
            var rows = await connection.ExecuteAsync(sql, new { Code = code });
            return rows > 0;
        }
    }
}
