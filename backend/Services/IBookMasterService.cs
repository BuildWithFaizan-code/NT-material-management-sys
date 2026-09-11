using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IBookMasterService
    {
        Task<IEnumerable<BookMasterSummaryDto>> GetAllBooksAsync();
        Task<IEnumerable<BookDetailDto>> GetAllBooksWithDetailsAsync();
        Task<BookDetailDto?> GetBookDetailsAsync(int bookCode);
        Task<IEnumerable<CategoryDto>> GetAvailableCategoriesAsync(int bookCode);
        Task<int> GetNextBookCodeAsync();
        Task<bool> SaveBookAsync(BookSaveDto model);
        Task<bool> DeleteBookAsync(int bookCode);
    }
}
