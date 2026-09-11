using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class BookMasterService : IBookMasterService
    {
        private readonly IBookMasterRepository _repository;

        public BookMasterService(IBookMasterRepository repository)
        {
            _repository = repository;
        }

        public Task<IEnumerable<BookMasterSummaryDto>> GetAllBooksAsync() => _repository.GetAllBooksAsync();
        public Task<IEnumerable<BookDetailDto>> GetAllBooksWithDetailsAsync() => _repository.GetAllBooksWithDetailsAsync();
        public Task<BookDetailDto?> GetBookDetailsAsync(int bookCode) => _repository.GetBookDetailsAsync(bookCode);
        public Task<IEnumerable<CategoryDto>> GetAvailableCategoriesAsync(int bookCode) => _repository.GetAvailableCategoriesAsync(bookCode);
        public Task<int> GetNextBookCodeAsync() => _repository.GetNextBookCodeAsync();
        public Task<bool> SaveBookAsync(BookSaveDto model) => _repository.SaveBookAsync(model);
        public Task<bool> DeleteBookAsync(int bookCode) => _repository.DeleteBookAsync(bookCode);
    }
}
