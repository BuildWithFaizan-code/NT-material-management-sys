using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class StoreMasterRepository : IStoreMasterRepository
    {
        private readonly string _connectionString;

        public StoreMasterRepository(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
        }

        private static void SanitizeModel(StoreMaster model)
        {
            model.StrName = model.StrName?.Trim() ?? string.Empty;
            if (model.StrName.Length > 100)
            {
                model.StrName = model.StrName.Substring(0, 100);
            }

            if (!string.IsNullOrWhiteSpace(model.StrSeries))
            {
                model.StrSeries = model.StrSeries.Trim();
                if (model.StrSeries.Length > 8)
                {
                    model.StrSeries = model.StrSeries.Substring(0, 8);
                }
            }

            if (!string.IsNullOrWhiteSpace(model.StrFixChar))
            {
                model.StrFixChar = model.StrFixChar.Trim();
                if (model.StrFixChar.Length > 3)
                {
                    model.StrFixChar = model.StrFixChar.Substring(0, 3);
                }
            }
        }

        private async Task EnsureTableExistsAsync(SqlConnection connection)
        {
            const string sql = @"
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'STOREMST' OR name = 'StoreMst')
                BEGIN
                    CREATE TABLE StoreMst (
                        Str_Code INT PRIMARY KEY,
                        Str_Name VARCHAR(100) NOT NULL,
                        Loc_Code INT NULL,
                        Str_Series VARCHAR(50) NULL,
                        Str_FixChar VARCHAR(50) NULL
                    );
                END;";
            await connection.ExecuteAsync(sql);
        }

        private async Task<string> GetTableNameAsync(SqlConnection connection)
        {
            const string sql = "SELECT TOP 1 name FROM sys.tables WHERE name IN ('STOREMST', 'StoreMst') ORDER BY name ASC;";
            var tableName = await connection.QueryFirstOrDefaultAsync<string>(sql);
            return string.IsNullOrEmpty(tableName) ? "StoreMst" : tableName;
        }

        public async Task<IEnumerable<StoreMaster>> GetAllAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            await EnsureTableExistsAsync(connection);

            var table = await GetTableNameAsync(connection);

            string sql = $@"
                IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('{table}') AND name = 'STR_CODE')
                BEGIN
                    SELECT 
                        SM.STR_CODE AS StrCode, 
                        SM.STR_NAME AS StrName, 
                        ISNULL(SM.LOC_CODE, 0) AS LocCode, 
                        ISNULL(LM.LOCATION, ISNULL(LM2.Location, '')) AS LocationName, 
                        SM.STR_SERIES AS StrSeries, 
                        SM.STR_FIXCHAR AS StrFixChar 
                    FROM {table} AS SM 
                    LEFT OUTER JOIN LOCATIONMST AS LM ON SM.LOC_CODE = LM.LOC_CODE 
                    LEFT OUTER JOIN LocationMst AS LM2 ON SM.LOC_CODE = LM2.Loc_Code
                    ORDER BY SM.STR_CODE ASC;
                END
                ELSE
                BEGIN
                    SELECT 
                        SM.Str_Code AS StrCode, 
                        SM.Str_Name AS StrName, 
                        ISNULL(SM.Loc_Code, 0) AS LocCode, 
                        ISNULL(LM.LOCATION, ISNULL(LM2.Location, '')) AS LocationName, 
                        SM.Str_Series AS StrSeries, 
                        SM.Str_FixChar AS StrFixChar 
                    FROM {table} AS SM 
                    LEFT OUTER JOIN LOCATIONMST AS LM ON SM.Loc_Code = LM.LOC_CODE 
                    LEFT OUTER JOIN LocationMst AS LM2 ON SM.Loc_Code = LM2.Loc_Code
                    ORDER BY SM.Str_Code ASC;
                END";

            return await connection.QueryAsync<StoreMaster>(sql);
        }

        public async Task<IEnumerable<LocationLookupDto>> GetLocationLookupAsync()
        {
            using var connection = new SqlConnection(_connectionString);

            const string sql = @"
                IF OBJECT_ID('LOCATIONMST') IS NOT NULL
                BEGIN
                    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('LOCATIONMST') AND name = 'MODE')
                        SELECT LOCATION AS LocationName, LOC_CODE AS LocCode FROM LOCATIONMST WHERE MODE = 'LOCATION' OR MODE = 'Location' OR MODE IS NULL ORDER BY LOCATION ASC;
                    ELSE
                        SELECT LOCATION AS LocationName, LOC_CODE AS LocCode FROM LOCATIONMST ORDER BY LOCATION ASC;
                END
                ELSE IF OBJECT_ID('LocationMst') IS NOT NULL
                BEGIN
                    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('LocationMst') AND name = 'Mode')
                        SELECT Location AS LocationName, Loc_Code AS LocCode FROM LocationMst WHERE Mode = 'LOCATION' OR Mode = 'Location' OR Mode IS NULL ORDER BY Location ASC;
                    ELSE
                        SELECT Location AS LocationName, Loc_Code AS LocCode FROM LocationMst ORDER BY Location ASC;
                END
                ELSE
                BEGIN
                    SELECT 'AHMEDABAD' AS LocationName, 1 AS LocCode
                    UNION ALL SELECT 'INDORE', 2
                    UNION ALL SELECT 'PUNE', 3
                    UNION ALL SELECT 'SURAT', 4;
                END";

            return await connection.QueryAsync<LocationLookupDto>(sql);
        }

        public async Task<int> GetNextCodeAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            await EnsureTableExistsAsync(connection);

            var table = await GetTableNameAsync(connection);

            string sql = $@"
                IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('{table}') AND name = 'STR_CODE')
                    SELECT ISNULL(MAX(STR_CODE), 0) + 1 FROM {table};
                ELSE
                    SELECT ISNULL(MAX(Str_Code), 0) + 1 FROM {table};";

            return await connection.ExecuteScalarAsync<int>(sql);
        }

        public async Task<bool> CreateAsync(StoreMaster model)
        {
            using var connection = new SqlConnection(_connectionString);
            await EnsureTableExistsAsync(connection);

            SanitizeModel(model);

            var table = await GetTableNameAsync(connection);

            if (model.StrCode <= 0)
            {
                model.StrCode = await GetNextCodeAsync();
            }

            string sql = $@"
                DECLARE @isIdentity INT = 0;
                SELECT @isIdentity = OBJECTPROPERTY(OBJECT_ID('{table}'), 'TableHasIdentity');

                IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('{table}') AND name = 'STR_CODE')
                BEGIN
                    IF @isIdentity = 1
                    BEGIN
                        SET IDENTITY_INSERT {table} ON;
                        INSERT INTO {table} (STR_CODE, STR_NAME, LOC_CODE, STR_SERIES, STR_FIXCHAR) 
                        VALUES (@StrCode, @StrName, @LocCode, @StrSeries, @StrFixChar);
                        SET IDENTITY_INSERT {table} OFF;
                    END
                    ELSE
                    BEGIN
                        INSERT INTO {table} (STR_CODE, STR_NAME, LOC_CODE, STR_SERIES, STR_FIXCHAR) 
                        VALUES (@StrCode, @StrName, @LocCode, @StrSeries, @StrFixChar);
                    END
                END
                ELSE
                BEGIN
                    IF @isIdentity = 1
                    BEGIN
                        SET IDENTITY_INSERT {table} ON;
                        INSERT INTO {table} (Str_Code, Str_Name, Loc_Code, Str_Series, Str_FixChar) 
                        VALUES (@StrCode, @StrName, @LocCode, @StrSeries, @StrFixChar);
                        SET IDENTITY_INSERT {table} OFF;
                    END
                    ELSE
                    BEGIN
                        INSERT INTO {table} (Str_Code, Str_Name, Loc_Code, Str_Series, Str_FixChar) 
                        VALUES (@StrCode, @StrName, @LocCode, @StrSeries, @StrFixChar);
                    END
                END;";

            try
            {
                var rows = await connection.ExecuteAsync(sql, model);
                return true;
            }
            catch (Exception)
            {
                // Fallback if IDENTITY_INSERT explicit code is not accepted
                string fallbackSql = $@"
                    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('{table}') AND name = 'STR_NAME')
                    BEGIN
                        INSERT INTO {table} (STR_NAME, LOC_CODE, STR_SERIES, STR_FIXCHAR) 
                        VALUES (@StrName, @LocCode, @StrSeries, @StrFixChar);
                    END
                    ELSE
                    BEGIN
                        INSERT INTO {table} (Str_Name, Loc_Code, Str_Series, Str_FixChar) 
                        VALUES (@StrName, @LocCode, @StrSeries, @StrFixChar);
                    END;";
                var rows = await connection.ExecuteAsync(fallbackSql, model);
                return rows > 0;
            }
        }

        public async Task<bool> UpdateAsync(int code, StoreMaster model)
        {
            using var connection = new SqlConnection(_connectionString);
            await EnsureTableExistsAsync(connection);

            SanitizeModel(model);

            var table = await GetTableNameAsync(connection);

            string sql = $@"
                IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('{table}') AND name = 'STR_CODE')
                BEGIN
                    UPDATE {table} 
                    SET STR_NAME = @StrName, 
                        LOC_CODE = @LocCode, 
                        STR_SERIES = @StrSeries, 
                        STR_FIXCHAR = @StrFixChar 
                    WHERE STR_CODE = @StrCode;
                END
                ELSE
                BEGIN
                    UPDATE {table} 
                    SET Str_Name = @StrName, 
                        Loc_Code = @LocCode, 
                        Str_Series = @StrSeries, 
                        Str_FixChar = @StrFixChar 
                    WHERE Str_Code = @StrCode;
                END";

            var rows = await connection.ExecuteAsync(sql, new { 
                StrCode = code, 
                model.StrName, 
                model.LocCode,
                model.StrSeries,
                model.StrFixChar
            });
            return rows > 0;
        }

        public async Task<bool> DeleteAsync(int code)
        {
            using var connection = new SqlConnection(_connectionString);
            await EnsureTableExistsAsync(connection);

            var table = await GetTableNameAsync(connection);

            string sql = $@"
                IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('{table}') AND name = 'STR_CODE')
                    DELETE FROM {table} WHERE STR_CODE = @Code;
                ELSE
                    DELETE FROM {table} WHERE Str_Code = @Code;";

            var rows = await connection.ExecuteAsync(sql, new { Code = code });
            return rows > 0;
        }
    }
}
