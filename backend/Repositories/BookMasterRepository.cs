using Dapper;
using Microsoft.Data.SqlClient;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public class BookMasterRepository : IBookMasterRepository
    {
        private readonly string _connectionString;

        public BookMasterRepository(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
            EnsureColumnsExist();
        }

        private void EnsureColumnsExist()
        {
            try
            {
                using var connection = new SqlConnection(_connectionString);
                const string migrationSql = @"
                    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('BOOKMST') AND name = 'GRN')
                        ALTER TABLE BOOKMST ADD GRN NVARCHAR(50) NULL;
                    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('BOOKMST') AND name = 'ISSUE')
                        ALTER TABLE BOOKMST ADD ISSUE NVARCHAR(50) NULL;
                    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('BOOKMST') AND name = 'JOB_ISSUE')
                        ALTER TABLE BOOKMST ADD JOB_ISSUE NVARCHAR(50) NULL;
                    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('BOOKMST') AND name = 'JOB_RECEIPT')
                        ALTER TABLE BOOKMST ADD JOB_RECEIPT NVARCHAR(50) NULL;";
                connection.Execute(migrationSql);
            }
            catch
            {
                // Ignore migration errors if database is read-only or permissions are restricted
            }
        }

        public async Task<IEnumerable<BookMasterSummaryDto>> GetAllBooksAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT DISTINCT 
                    BOOK_CODE AS BookCode, 
                    ISNULL(BOOK_NAME, '') AS BookName,
                    ISNULL(GRN, '') AS Grn,
                    ISNULL(ISSUE, '') AS Issue,
                    ISNULL(JOB_ISSUE, '') AS JobIssue,
                    ISNULL(JOB_RECEIPT, '') AS JobReceipt
                FROM BOOKMST 
                ORDER BY BOOK_NAME;";
            return await connection.QueryAsync<BookMasterSummaryDto>(sql);
        }

        public async Task<IEnumerable<BookDetailDto>> GetAllBooksWithDetailsAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string booksSql = @"
                SELECT 
                    BOOK_CODE AS BookCode, 
                    ISNULL(BOOK_NAME, '') AS BookName, 
                    ISNULL(GRN, '') AS Grn, 
                    ISNULL(ISSUE, '') AS Issue, 
                    ISNULL(JOB_ISSUE, '') AS JobIssue, 
                    ISNULL(JOB_RECEIPT, '') AS JobReceipt 
                FROM BOOKMST 
                ORDER BY BOOK_NAME;";
            
            var books = (await connection.QueryAsync<BookDetailDto>(booksSql)).ToList();

            const string catsSql = @"
                SELECT 
                    BD.BOOK_CODE AS BookCode,
                    CM.CAT_CODE AS CatCode, 
                    CM.CAT_NAME AS CatName 
                FROM BOOKDET BD 
                INNER JOIN CATEGORYMST CM ON BD.CAT_CODE = CM.CAT_CODE 
                ORDER BY CM.CAT_NAME;";

            var catLookup = (await connection.QueryAsync<(int BookCode, int CatCode, string CatName)>(catsSql))
                .GroupBy(x => x.BookCode)
                .ToDictionary(g => g.Key, g => g.Select(x => new CategoryDto { CatCode = x.CatCode, CatName = x.CatName }).ToList());

            foreach (var b in books)
            {
                if (catLookup.TryGetValue(b.BookCode, out var cats))
                {
                    b.Categories = cats;
                }
            }

            return books;
        }

        public async Task<BookDetailDto?> GetBookDetailsAsync(int bookCode)
        {
            using var connection = new SqlConnection(_connectionString);
            const string bookSql = @"
                SELECT 
                    BOOK_CODE AS BookCode, 
                    ISNULL(BOOK_NAME, '') AS BookName, 
                    ISNULL(GRN, '') AS Grn, 
                    ISNULL(ISSUE, '') AS Issue, 
                    ISNULL(JOB_ISSUE, '') AS JobIssue, 
                    ISNULL(JOB_RECEIPT, '') AS JobReceipt 
                FROM BOOKMST 
                WHERE BOOK_CODE = @BookCode;";

            var book = await connection.QueryFirstOrDefaultAsync<BookDetailDto>(bookSql, new { BookCode = bookCode });
            if (book == null) return null;

            const string catsSql = @"
                SELECT 
                    CM.CAT_CODE AS CatCode, 
                    CM.CAT_NAME AS CatName 
                FROM CATEGORYMST CM 
                INNER JOIN BOOKDET BD ON CM.CAT_CODE = BD.CAT_CODE 
                WHERE BD.BOOK_CODE = @BookCode 
                ORDER BY CM.CAT_NAME;";

            var categories = await connection.QueryAsync<CategoryDto>(catsSql, new { BookCode = bookCode });
            book.Categories = categories.ToList();
            return book;
        }

        public async Task<IEnumerable<CategoryDto>> GetAvailableCategoriesAsync(int bookCode)
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = @"
                SELECT 
                    CAT_CODE AS CatCode, 
                    CAT_NAME AS CatName 
                FROM CATEGORYMST 
                WHERE CAT_CODE NOT IN (
                    SELECT CAT_CODE FROM BOOKDET WHERE BOOK_CODE = @BookCode
                ) 
                ORDER BY CAT_NAME;";
            return await connection.QueryAsync<CategoryDto>(sql, new { BookCode = bookCode });
        }

        public async Task<int> GetNextBookCodeAsync()
        {
            using var connection = new SqlConnection(_connectionString);
            const string sql = "SELECT ISNULL(MAX(BOOK_CODE), 0) + 1 FROM BOOKMST;";
            return await connection.ExecuteScalarAsync<int>(sql);
        }

        public async Task<bool> SaveBookAsync(BookSaveDto model)
        {
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            using var transaction = connection.BeginTransaction();

            try
            {
                if (model.BookCode <= 0)
                {
                    const string nextCodeSql = "SELECT ISNULL(MAX(BOOK_CODE), 0) + 1 FROM BOOKMST;";
                    model.BookCode = await connection.ExecuteScalarAsync<int>(nextCodeSql, transaction: transaction);
                }

                const string checkSql = "SELECT COUNT(1) FROM BOOKMST WHERE BOOK_CODE = @BookCode;";
                var exists = await connection.ExecuteScalarAsync<int>(checkSql, new { BookCode = model.BookCode }, transaction: transaction) > 0;

                if (exists)
                {
                    const string updateSql = @"
                        UPDATE BOOKMST 
                        SET 
                            BOOK_NAME = @BookName, 
                            GRN = @Grn, 
                            ISSUE = @Issue, 
                            JOB_ISSUE = @JobIssue, 
                            JOB_RECEIPT = @JobReceipt 
                        WHERE BOOK_CODE = @BookCode;";
                    await connection.ExecuteAsync(updateSql, model, transaction: transaction);
                }
                else
                {
                    const string insertSql = @"
                        INSERT INTO BOOKMST (
                            BOOK_CODE, 
                            BOOK_NAME, 
                            GRN, 
                            ISSUE, 
                            JOB_ISSUE, 
                            JOB_RECEIPT
                        ) VALUES (
                            @BookCode, 
                            @BookName, 
                            @Grn, 
                            @Issue, 
                            @JobIssue, 
                            @JobReceipt
                        );";
                    await connection.ExecuteAsync(insertSql, model, transaction: transaction);
                }

                // Delete existing allocations
                const string deleteDetSql = "DELETE FROM BOOKDET WHERE BOOK_CODE = @BookCode;";
                await connection.ExecuteAsync(deleteDetSql, new { BookCode = model.BookCode }, transaction: transaction);

                // Insert updated category allocations
                if (model.SelectedCatCodes != null && model.SelectedCatCodes.Count > 0)
                {
                    const string insertDetSql = "INSERT INTO BOOKDET (BOOK_CODE, CAT_CODE) VALUES (@BookCode, @CatCode);";
                    foreach (var catCode in model.SelectedCatCodes)
                    {
                        await connection.ExecuteAsync(insertDetSql, new { BookCode = model.BookCode, CatCode = catCode }, transaction: transaction);
                    }
                }

                transaction.Commit();
                return true;
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }

        public async Task<bool> DeleteBookAsync(int bookCode)
        {
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            using var transaction = connection.BeginTransaction();

            try
            {
                const string deleteDetSql = "DELETE FROM BOOKDET WHERE BOOK_CODE = @BookCode;";
                await connection.ExecuteAsync(deleteDetSql, new { BookCode = bookCode }, transaction: transaction);

                const string deleteMstSql = "DELETE FROM BOOKMST WHERE BOOK_CODE = @BookCode;";
                var rows = await connection.ExecuteAsync(deleteMstSql, new { BookCode = bookCode }, transaction: transaction);

                transaction.Commit();
                return rows > 0;
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }
    }
}
