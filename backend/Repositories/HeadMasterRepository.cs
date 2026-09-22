using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class HeadMasterRepository : IHeadMasterRepository
    {
        private readonly string _connectionString;

        public HeadMasterRepository(IConfiguration configuration)
        {
            _connectionString = Environment.GetEnvironmentVariable("CONNECTION_STRING")
                ?? configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
        }

        public async Task<IEnumerable<HeadMasterDto>> GetAllAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    LOC_CODE AS LocCode, 
                    LOCATION AS Location, 
                    MODE AS Mode, 
                    LOC_SERIES AS LocSeries 
                FROM LOCATIONMST 
                WHERE MODE = 'COSTING HEAD' 
                ORDER BY LOCATION;";
            return await connection.QueryAsync<HeadMasterDto>(sql);
        }

        public async Task<HeadMasterDto?> GetByCodeAsync(int code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    LOC_CODE AS LocCode, 
                    LOCATION AS Location, 
                    MODE AS Mode, 
                    LOC_SERIES AS LocSeries 
                FROM LOCATIONMST 
                WHERE LOC_CODE = @Code AND MODE = 'COSTING HEAD';";
            return await connection.QueryFirstOrDefaultAsync<HeadMasterDto>(sql, new { Code = code });
        }

        public async Task<int> GetNextCodeAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "SELECT ISNULL(MAX(LOC_CODE), 0) + 1 FROM LOCATIONMST;";
            return await connection.ExecuteScalarAsync<int>(sql);
        }

        public async Task<bool> CreateAsync(CreateHeadMasterDto model)
        {
            using var connection = new SqlConnection(_connectionString);
            if (model.LocCode <= 0)
            {
                model.LocCode = await GetNextCodeAsync();
            }

            const string sql = @"
                INSERT INTO LOCATIONMST (LOC_CODE, LOCATION, MODE, LOC_SERIES) 
                VALUES (@LocCode, @Location, 'COSTING HEAD', @LocSeries);";
            var rows = await connection.ExecuteAsync(sql, new {
                LocCode = model.LocCode,
                Location = model.Location,
                LocSeries = model.LocSeries ?? string.Empty
            });
            return rows > 0;
        }

        public async Task<bool> UpdateAsync(int code, CreateHeadMasterDto model)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                UPDATE LOCATIONMST 
                SET LOCATION = @Location, 
                    LOC_SERIES = @LocSeries 
                WHERE LOC_CODE = @Code AND MODE = 'COSTING HEAD';";
            var rows = await connection.ExecuteAsync(sql, new { 
                Code = code, 
                Location = model.Location,
                LocSeries = model.LocSeries ?? string.Empty
            });
            return rows > 0;
        }

        public async Task<bool> DeleteAsync(int code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "DELETE FROM LOCATIONMST WHERE LOC_CODE = @Code AND MODE = 'COSTING HEAD';";
            var rows = await connection.ExecuteAsync(sql, new { Code = code });
            return rows > 0;
        }
    }
}
