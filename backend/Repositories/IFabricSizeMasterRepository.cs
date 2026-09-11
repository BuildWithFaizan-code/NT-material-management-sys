using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IFabricSizeMasterRepository
    {
        Task<IEnumerable<FabricSizeMasterDto>> GetAllAsync();
        Task<int> GetNextCodeAsync();
        Task<bool> InsertAsync(FabricSizeMasterDto item);
        Task<bool> UpdateAsync(FabricSizeMasterDto item);
        Task<bool> DeleteAsync(int sizeCode);
    }
}
