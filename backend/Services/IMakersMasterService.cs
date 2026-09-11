using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IMakersMasterService
    {
        Task<IEnumerable<MakersMasterDto>> GetAllAsync();
        Task<int> GetNextCodeAsync();
        Task<bool> InsertAsync(MakersMasterDto item);
        Task<bool> UpdateAsync(MakersMasterDto item);
        Task<bool> DeleteAsync(int makerCode);
    }
}
