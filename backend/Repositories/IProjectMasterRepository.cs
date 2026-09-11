using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IProjectMasterRepository
    {
        Task<IEnumerable<ProjectMasterDto>> GetAllAsync();
        Task<int> GetNextCodeAsync();
        Task<bool> CreateAsync(ProjectMasterDto dto);
        Task<bool> UpdateAsync(ProjectMasterDto dto);
        Task<bool> DeleteAsync(int code);
    }
}
