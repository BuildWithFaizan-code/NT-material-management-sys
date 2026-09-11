using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IOperatorMasterRepository
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
