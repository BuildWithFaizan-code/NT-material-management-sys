using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class NonStockableItemService : INonStockableItemService
    {
        private readonly INonStockableItemRepository _repository;

        public NonStockableItemService(INonStockableItemRepository repository)
        {
            _repository = repository;
        }

        public Task<IEnumerable<NonStockableItemDto>> GetAllAsync() => _repository.GetAllAsync();
        public Task<NonStockableItemDto?> GetByCodeAsync(string code) => _repository.GetByCodeAsync(code);
        public Task<IEnumerable<UnassignedItemDto>> GetUnassignedItemsAsync() => _repository.GetUnassignedItemsAsync();
        public Task<NonStockableDropdownsDto> GetDropdownsAsync() => _repository.GetDropdownsAsync();
        public Task<bool> SaveAsync(SaveNonStockableItemDto model) => _repository.SaveAsync(model);
        public Task<bool> DeleteAsync(string code) => _repository.DeleteAsync(code);
    }
}
