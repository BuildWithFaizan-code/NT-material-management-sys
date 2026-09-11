using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IProjectMasterService
    {
        Task<IEnumerable<ProjectMasterDto>> GetAllAsync();
        Task<int> GetNextCodeAsync();
        Task<bool> CreateAsync(ProjectMasterDto dto);
        Task<bool> UpdateAsync(ProjectMasterDto dto);
        Task<bool> DeleteAsync(int code);
    }
}
