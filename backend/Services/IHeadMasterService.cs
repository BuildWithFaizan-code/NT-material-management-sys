using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IHeadMasterService
    {
        Task<IEnumerable<HeadMasterDto>> GetAllAsync();
        Task<HeadMasterDto?> GetByCodeAsync(int code);
        Task<int> GetNextCodeAsync();
        Task<bool> CreateAsync(CreateHeadMasterDto model);
        Task<bool> UpdateAsync(int code, CreateHeadMasterDto model);
        Task<bool> DeleteAsync(int code);
    }
}
