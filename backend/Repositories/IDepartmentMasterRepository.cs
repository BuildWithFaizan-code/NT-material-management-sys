using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IDepartmentMasterRepository
    {
        Task<IEnumerable<DepartmentMasterDto>> GetAllAsync();
        Task<IEnumerable<PartyAccountDto>> GetAccountsAsync();
        Task<IEnumerable<PartyAccountLookupDto>> GetAccountsLookupAsync(string search);
        Task<DepartmentMasterDto?> GetByCodeAsync(int code);
        Task<int> GetNextCodeAsync();
        Task<bool> CreateAsync(CreateDepartmentDto model);
        Task<bool> UpdateAsync(int code, CreateDepartmentDto model);
        Task<bool> DeleteAsync(int code);
    }
}
