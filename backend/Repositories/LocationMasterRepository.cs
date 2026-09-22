using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class LocationMasterRepository : ILocationMasterRepository
    {
        private readonly string _connectionString;

        public LocationMasterRepository(IConfiguration configuration)
        {
            _connectionString = MMSERP.Api.Common.DbConnectionHelper.ResolveConnectionString(configuration);
        }

        public async Task<IEnumerable<LocationMaster>> GetAllAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    Loc_Code AS LocCode, 
                    Location AS LocName, 
                    Mode AS LocPrefix, 
                    LOC_SERIES AS LocSeries 
                FROM LocationMst 
                ORDER BY Loc_Code ASC;";
            return await connection.QueryAsync<LocationMaster>(sql);
        }

        public async Task<LocationMaster?> GetByCodeAsync(int code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    Loc_Code AS LocCode, 
                    Location AS LocName, 
                    Mode AS LocPrefix, 
                    LOC_SERIES AS LocSeries 
                FROM LocationMst 
                WHERE Loc_Code = @Code;";
            return await connection.QueryFirstOrDefaultAsync<LocationMaster>(sql, new { Code = code });
        }

        public async Task<int> GetNextCodeAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "SELECT ISNULL(MAX(Loc_Code), 0) + 1 FROM LocationMst;";
            return await connection.ExecuteScalarAsync<int>(sql);
        }

        public async Task<bool> CreateAsync(LocationMaster model)
        {
            using var connection = new SqlConnection(_connectionString);
            if (model.LocCode <= 0)
            {
                model.LocCode = await GetNextCodeAsync();
            }

            const string sql = @"
                INSERT INTO LocationMst (Loc_Code, Location, Mode, LOC_SERIES) 
                VALUES (@LocCode, @LocName, @LocPrefix, @LocSeries);";
            var rows = await connection.ExecuteAsync(sql, model);
            return rows > 0;
        }

        public async Task<bool> UpdateAsync(int code, LocationMaster model)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                UPDATE LocationMst 
                SET Location = @LocName, 
                    Mode = @LocPrefix, 
                    LOC_SERIES = @LocSeries 
                WHERE Loc_Code = @LocCode;";
            var rows = await connection.ExecuteAsync(sql, new { 
                LocCode = code, 
                model.LocName, 
                model.LocPrefix,
                model.LocSeries
            });
            return rows > 0;
        }

        public async Task<bool> DeleteAsync(int code)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "DELETE FROM LocationMst WHERE Loc_Code = @Code;";
            var rows = await connection.ExecuteAsync(sql, new { Code = code });
            return rows > 0;
        }
    }
}
