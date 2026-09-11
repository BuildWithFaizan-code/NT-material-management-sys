using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface INonStockableItemService
    {
        Task<IEnumerable<NonStockableItemDto>> GetAllAsync();
        Task<NonStockableItemDto?> GetByCodeAsync(string code);
        Task<IEnumerable<UnassignedItemDto>> GetUnassignedItemsAsync();
        Task<NonStockableDropdownsDto> GetDropdownsAsync();
        Task<bool> SaveAsync(SaveNonStockableItemDto model);
        Task<bool> DeleteAsync(string code);
    }
}
