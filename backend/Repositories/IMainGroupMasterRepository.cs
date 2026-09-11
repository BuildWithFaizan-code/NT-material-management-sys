using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IMainGroupMasterRepository
    {
        Task<IEnumerable<MainGroupMasterDto>> GetAllAsync(string? searchTerm = null);
        Task<MainGroupMasterDto?> GetByCodeAsync(string wipCode);
        Task<bool> InsertAsync(MainGroupMasterDto dto);
        Task<bool> UpdateAsync(MainGroupMasterDto dto);
        Task<bool> DeleteAsync(string wipCode);
        Task<string> GetNextCodeAsync();
    }
}
