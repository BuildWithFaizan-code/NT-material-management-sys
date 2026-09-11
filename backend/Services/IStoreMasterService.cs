using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IStoreMasterService
    {
        Task<IEnumerable<StoreMaster>> GetAllAsync();
        Task<IEnumerable<LocationLookupDto>> GetLocationLookupAsync();
        Task<int> GetNextCodeAsync();
        Task<bool> CreateAsync(StoreMaster model);
        Task<bool> UpdateAsync(int code, StoreMaster model);
        Task<bool> DeleteAsync(int code);
    }
}
