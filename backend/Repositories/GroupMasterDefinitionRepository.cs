using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class GroupMasterDefinitionRepository : IGroupMasterDefinitionRepository
    {
        private readonly string _connectionString;

        public GroupMasterDefinitionRepository(IConfiguration configuration)
        {
            _connectionString = Environment.GetEnvironmentVariable("CONNECTION_STRING")
                ?? configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
        }

        private IDbConnection CreateConnection() => new SqlConnection(_connectionString);

        public async Task EnsureTablesCreatedAsync()
        {
            using var connection = CreateConnection();
            const string sql = @"
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ITEMSUBMST' OR name = 'ItemSubMst')
                BEGIN
                    CREATE TABLE ITEMSUBMST (
                        ISM_MSCODE VARCHAR(50) NOT NULL PRIMARY KEY,
                        ISM_MCODE VARCHAR(50) NOT NULL,
                        ISM_SUBCODE VARCHAR(50) NOT NULL,
                        ISM_SUBCATCODE VARCHAR(50) NOT NULL
                    );
                END";

            await connection.ExecuteAsync(sql);
        }

        public async Task<IEnumerable<GroupMasterDefinitionDto>> GetMappedDefinitionsAsync(string? mCode)
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"
                SELECT 
                    sub.ISM_MSCODE AS IsmMsCode,
                    sub.ISM_MCODE AS IsmMCode,
                    sub.ISM_SUBCODE AS IsmSubCode,
                    sub.ISM_SUBCATCODE AS IsmSubCatCode,
                    ISNULL(cat.CAT_NAME, '') AS CatName,
                    ISNULL(cat.CAT_SHORT, '') AS CatShort,
                    ISNULL(wip.WIP_NAME, '') AS WipName
                FROM ITEMSUBMST sub
                LEFT JOIN CATEGORYMST cat ON sub.ISM_SUBCATCODE = cat.CAT_CODE
                LEFT JOIN WIPMST wip ON sub.ISM_MCODE = wip.WIP_CODE
                WHERE (@MCode IS NULL OR @MCode = '' OR sub.ISM_MCODE = @MCode)
                ORDER BY TRY_CAST(sub.ISM_MSCODE AS INT), sub.ISM_MSCODE;";

            return await connection.QueryAsync<GroupMasterDefinitionDto>(sql, new { MCode = mCode });
        }

        public async Task<GroupMasterDefinitionDto?> GetByMsCodeAsync(string msCode)
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"
                SELECT 
                    sub.ISM_MSCODE AS IsmMsCode,
                    sub.ISM_MCODE AS IsmMCode,
                    sub.ISM_SUBCODE AS IsmSubCode,
                    sub.ISM_SUBCATCODE AS IsmSubCatCode,
                    ISNULL(cat.CAT_NAME, '') AS CatName,
                    ISNULL(cat.CAT_SHORT, '') AS CatShort,
                    ISNULL(wip.WIP_NAME, '') AS WipName
                FROM ITEMSUBMST sub
                LEFT JOIN CATEGORYMST cat ON sub.ISM_SUBCATCODE = cat.CAT_CODE
                LEFT JOIN WIPMST wip ON sub.ISM_MCODE = wip.WIP_CODE
                WHERE sub.ISM_MSCODE = @MsCode;";

            return await connection.QueryFirstOrDefaultAsync<GroupMasterDefinitionDto>(sql, new { MsCode = msCode });
        }

        public async Task<IEnumerable<CategoryLookupDto>> GetCategoriesAsync()
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"
                SELECT 
                    CAT_CODE AS CatCode, 
                    CAT_NAME AS CatName 
                FROM CATEGORYMST 
                ORDER BY CAT_NAME;";

            return await connection.QueryAsync<CategoryLookupDto>(sql);
        }

        public async Task<IEnumerable<MainGroupLookupDto>> GetMainGroupsAsync()
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"
                SELECT 
                    WIP_CODE AS WipCode, 
                    WIP_NAME AS WipName 
                FROM WIPMST 
                ORDER BY TRY_CAST(WIP_CODE AS INT), WIP_CODE;";

            return await connection.QueryAsync<MainGroupLookupDto>(sql);
        }

        public async Task<string?> GetMainGroupNameByCodeAsync(string mCode)
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"SELECT WIP_NAME FROM WIPMST WHERE WIP_CODE = @MCode;";

            return await connection.ExecuteScalarAsync<string?>(sql, new { MCode = mCode });
        }

        public async Task<bool> InsertAsync(GroupMasterDefinitionDto dto)
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"
                INSERT INTO ItemSubMst (
                    ISM_MCode, 
                    ISM_SubCode, 
                    ISM_SubCatCode, 
                    ISM_MSCode
                ) VALUES (
                    @IsmMCode, 
                    @IsmSubCode, 
                    @IsmSubCatCode, 
                    @IsmMsCode
                );

                IF EXISTS (SELECT * FROM sys.tables WHERE name = 'ITEMMST')
                BEGIN
                    UPDATE ITEMMST 
                    SET I_PREFIX = @IsmMCode 
                    FROM ITEMSUBMST 
                    WHERE I_CID = ISM_SUBCATCODE AND I_POSTFIX = ISM_SUBCODE;
                END";

            var rows = await connection.ExecuteAsync(sql, dto);
            return rows > 0;
        }

        public async Task<bool> UpdateAsync(GroupMasterDefinitionDto dto)
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"
                UPDATE ItemSubMst 
                SET ISM_MCode = @IsmMCode, 
                    ISM_SubCode = @IsmSubCode, 
                    ISM_SubCatCode = @IsmSubCatCode
                WHERE ISM_MSCode = @IsmMsCode;

                IF EXISTS (SELECT * FROM sys.tables WHERE name = 'ITEMMST')
                BEGIN
                    UPDATE ITEMMST 
                    SET I_PREFIX = @IsmMCode 
                    FROM ITEMSUBMST 
                    WHERE I_CID = ISM_SUBCATCODE AND I_POSTFIX = ISM_SUBCODE;
                END";

            var rows = await connection.ExecuteAsync(sql, dto);
            return rows > 0;
        }

        public async Task<bool> DeleteAsync(string msCode)
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"DELETE FROM ITEMSUBMST WHERE ISM_MSCODE = @MsCode;";

            var rows = await connection.ExecuteAsync(sql, new { MsCode = msCode });
            return rows > 0;
        }
    }
}
