using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface ILocationMasterRepository
    {
        Task<IEnumerable<LocationMaster>> GetAllAsync();
        Task<LocationMaster?> GetByCodeAsync(int code);
        Task<int> GetNextCodeAsync();
        Task<bool> CreateAsync(LocationMaster model);
        Task<bool> UpdateAsync(int code, LocationMaster model);
        Task<bool> DeleteAsync(int code);
    }
}
