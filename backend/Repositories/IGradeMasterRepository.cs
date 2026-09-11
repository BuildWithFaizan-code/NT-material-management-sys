using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IGradeMasterRepository
    {
        Task<IEnumerable<GradeMasterDto>> GetAllAsync();
        Task<int> GetNextSrlAsync();
        Task<bool> InsertAsync(GradeMasterDto item);
        Task<bool> UpdateAsync(GradeMasterDto item);
        Task<bool> DeleteAsync(int gradeSrl);
    }
}
