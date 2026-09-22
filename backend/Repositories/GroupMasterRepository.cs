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
    public class GroupMasterRepository : IGroupMasterRepository
    {
        private readonly string _connectionString;

        public GroupMasterRepository(IConfiguration configuration)
        {
            _connectionString = MMSERP.Api.Common.DbConnectionHelper.ResolveConnectionString(configuration);
        }

        private IDbConnection CreateConnection() => new SqlConnection(_connectionString);

        public async Task EnsureTablesCreatedAsync()
        {
            using var connection = CreateConnection();
            const string sql = @"
                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CategoryMst')
                BEGIN
                    CREATE TABLE CategoryMst (
                        Cat_Code VARCHAR(50) NOT NULL PRIMARY KEY,
                        Cat_Name VARCHAR(255) NOT NULL,
                        Cat_HSN VARCHAR(50) NULL,
                        Cat_TaxSlab VARCHAR(50) NULL,
                        Pallet_Req VARCHAR(10) NULL DEFAULT 'No',
                        Size_Req VARCHAR(10) NULL DEFAULT 'No',
                        Box_Req VARCHAR(10) NULL DEFAULT 'No',
                        Grade_Req VARCHAR(10) NULL DEFAULT 'No',
                        GSM_Req VARCHAR(10) NULL DEFAULT 'No',
                        Cat_Tol DECIMAL(18,2) NULL DEFAULT 0,
                        Cat_Short VARCHAR(50) NULL,
                        Pack_Type_Name VARCHAR(100) NULL
                    );
                END

                IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TAX_SLAB_MST')
                BEGIN
                    CREATE TABLE TAX_SLAB_MST (
                        TAX_CODE VARCHAR(50) NOT NULL PRIMARY KEY,
                        TAX_NAME VARCHAR(100) NOT NULL
                    );

                    INSERT INTO TAX_SLAB_MST (TAX_CODE, TAX_NAME) VALUES 
                    ('1', 'GST 5%'),
                    ('2', 'GST 12%'),
                    ('3', 'GST 18%'),
                    ('4', 'GST 28%'),
                    ('5', 'EXEMPT (0%)');
                END";

            await connection.ExecuteAsync(sql);
        }

        public async Task<IEnumerable<GroupMasterDto>> GetAllAsync(string? searchQuery)
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"
                SELECT 
                    Cat_Code AS CatCode,
                    Cat_Name AS CatName,
                    ISNULL(Cat_HSN, '') AS CatHsn,
                    ISNULL(Cat_TaxSlab, '') AS CatTaxSlab,
                    ISNULL(Pallet_Req, 'No') AS PalletReq,
                    ISNULL(Size_Req, 'No') AS SizeReq,
                    ISNULL(Box_Req, 'No') AS BoxReq,
                    ISNULL(Grade_Req, 'No') AS GradeReq,
                    ISNULL(GSM_Req, 'No') AS GsmReq,
                    ISNULL(Cat_Tol, 0) AS CatTol,
                    ISNULL(Cat_Short, '') AS CatShort,
                    ISNULL(Pack_Type_Name, '') AS PackTypeName
                FROM CategoryMst
                WHERE (@SearchQuery IS NULL 
                   OR Cat_Name LIKE '%' + @SearchQuery + '%' 
                   OR Cat_Code LIKE '%' + @SearchQuery + '%'
                   OR Cat_HSN LIKE '%' + @SearchQuery + '%')
                ORDER BY TRY_CAST(Cat_Code AS INT), Cat_Name;";

            return await connection.QueryAsync<GroupMasterDto>(sql, new { SearchQuery = searchQuery });
        }

        public async Task<GroupMasterDto?> GetByCodeAsync(string code)
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"
                SELECT 
                    Cat_Code AS CatCode,
                    Cat_Name AS CatName,
                    ISNULL(Cat_HSN, '') AS CatHsn,
                    ISNULL(Cat_TaxSlab, '') AS CatTaxSlab,
                    ISNULL(Pallet_Req, 'No') AS PalletReq,
                    ISNULL(Size_Req, 'No') AS SizeReq,
                    ISNULL(Box_Req, 'No') AS BoxReq,
                    ISNULL(Grade_Req, 'No') AS GradeReq,
                    ISNULL(GSM_Req, 'No') AS GsmReq,
                    ISNULL(Cat_Tol, 0) AS CatTol,
                    ISNULL(Cat_Short, '') AS CatShort,
                    ISNULL(Pack_Type_Name, '') AS PackTypeName
                FROM CategoryMst
                WHERE Cat_Code = @Code;";

            return await connection.QueryFirstOrDefaultAsync<GroupMasterDto>(sql, new { Code = code });
        }

        public async Task<string> GetNextCodeAsync()
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"SELECT ISNULL(MAX(TRY_CAST(Cat_Code AS BIGINT)), 0) + 1 FROM CategoryMst;";
            var nextVal = await connection.ExecuteScalarAsync<long>(sql);
            return nextVal.ToString();
        }

        public async Task<IEnumerable<TaxSlabDto>> GetTaxSlabsAsync()
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"SELECT TAX_CODE AS TaxCode, TAX_NAME AS TaxName FROM TAX_SLAB_MST ORDER BY TAX_NAME;";
            return await connection.QueryAsync<TaxSlabDto>(sql);
        }

        public async Task<bool> InsertAsync(GroupMasterDto item)
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"
                INSERT INTO CategoryMst (
                    Cat_Code, Cat_Name, Cat_HSN, Cat_TaxSlab, Pallet_Req, Size_Req, 
                    Box_Req, Grade_Req, GSM_Req, Cat_Tol, Cat_Short, Pack_Type_Name
                ) VALUES (
                    @CatCode, @CatName, @CatHsn, @CatTaxSlab, @PalletReq, @SizeReq, 
                    @BoxReq, @GradeReq, @GsmReq, @CatTol, @CatShort, @PackTypeName
                );";

            var rows = await connection.ExecuteAsync(sql, item);
            return rows > 0;
        }

        public async Task<bool> UpdateAsync(GroupMasterDto item)
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"
                UPDATE CategoryMst SET 
                    Cat_Name = @CatName,
                    Cat_HSN = @CatHsn,
                    Cat_TaxSlab = @CatTaxSlab,
                    Pallet_Req = @PalletReq,
                    Size_Req = @SizeReq,
                    Box_Req = @BoxReq,
                    Grade_Req = @GradeReq,
                    GSM_Req = @GsmReq,
                    Cat_Tol = @CatTol,
                    Cat_Short = @CatShort,
                    Pack_Type_Name = @PackTypeName
                WHERE Cat_Code = @CatCode;";

            var rows = await connection.ExecuteAsync(sql, item);
            return rows > 0;
        }

        public async Task<bool> DeleteAsync(string code)
        {
            await EnsureTablesCreatedAsync();
            using var connection = CreateConnection();

            const string sql = @"DELETE FROM CategoryMst WHERE Cat_Code = @Code;";
            var rows = await connection.ExecuteAsync(sql, new { Code = code });
            return rows > 0;
        }
    }
}
