using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IOperationMasterService
    {
        Task<IEnumerable<OperationMasterDto>> GetAllAsync();
        Task<OperationMasterDto?> GetByCodeAsync(int code);
        Task<int> GetNextCodeAsync();
        Task<bool> CreateAsync(CreateOperationDto model);
        Task<bool> UpdateAsync(int code, CreateOperationDto model);
        Task<bool> DeleteAsync(int code);
    }
}
