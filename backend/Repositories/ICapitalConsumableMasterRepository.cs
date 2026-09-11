using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface ICapitalConsumableMasterRepository
    {
        Task<IEnumerable<CapitalConsumableMasterDto>> GetAllAsync();
        Task<int> GetNextCodeAsync();
        Task<bool> InsertAsync(CapitalConsumableMasterDto item);
        Task<bool> UpdateAsync(CapitalConsumableMasterDto item);
        Task<bool> DeleteAsync(int code);
    }
}
