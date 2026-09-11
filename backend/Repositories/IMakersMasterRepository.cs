using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IMakersMasterRepository
    {
        Task<IEnumerable<MakersMasterDto>> GetAllAsync();
        Task<int> GetNextCodeAsync();
        Task<bool> InsertAsync(MakersMasterDto item);
        Task<bool> UpdateAsync(MakersMasterDto item);
        Task<bool> DeleteAsync(int makerCode);
    }
}
