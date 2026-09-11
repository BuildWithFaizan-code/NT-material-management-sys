using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IGradeMasterService
    {
        Task<IEnumerable<GradeMasterDto>> GetAllAsync();
        Task<int> GetNextSrlAsync();
        Task<bool> InsertAsync(GradeMasterDto item);
        Task<bool> UpdateAsync(GradeMasterDto item);
        Task<bool> DeleteAsync(int gradeSrl);
    }
}
