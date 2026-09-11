using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface ISubDepartmentMasterService
    {
        Task<IEnumerable<SubDepartmentMasterDto>> GetAllAsync();
        Task<SubDepartmentMasterDto?> GetByCodeAsync(int code);
        Task<int> GetNextCodeAsync();
        Task<bool> CreateAsync(CreateSubDepartmentDto model);
        Task<bool> UpdateAsync(int code, CreateSubDepartmentDto model);
        Task<bool> DeleteAsync(int code);
    }
}
