using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IOperatorMasterService
    {
        Task<IEnumerable<DepartmentDto>> GetDepartmentsAsync();
        Task<IEnumerable<OperatorMasterDto>> GetAllAsync();
        Task<OperatorMasterDto?> GetByCodeAsync(int code);
        Task<int> GetNextCodeAsync();
        Task<bool> CreateAsync(CreateOperatorDto model);
        Task<bool> UpdateAsync(int code, CreateOperatorDto model);
        Task<bool> DeleteAsync(int code);
    }
}
