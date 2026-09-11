using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class DepartmentMasterService : IDepartmentMasterService
    {
        private readonly IDepartmentMasterRepository _repository;

        public DepartmentMasterService(IDepartmentMasterRepository repository)
        {
            _repository = repository;
        }

        public Task<IEnumerable<DepartmentMasterDto>> GetAllAsync() => _repository.GetAllAsync();

        public Task<IEnumerable<PartyAccountDto>> GetAccountsAsync() => _repository.GetAccountsAsync();

        public Task<IEnumerable<PartyAccountLookupDto>> GetAccountsLookupAsync(string search) => _repository.GetAccountsLookupAsync(search);

        public Task<DepartmentMasterDto?> GetByCodeAsync(int code) => _repository.GetByCodeAsync(code);

        public Task<int> GetNextCodeAsync() => _repository.GetNextCodeAsync();

        public Task<bool> CreateAsync(CreateDepartmentDto model) => _repository.CreateAsync(model);

        public Task<bool> UpdateAsync(int code, CreateDepartmentDto model) => _repository.UpdateAsync(code, model);

        public Task<bool> DeleteAsync(int code) => _repository.DeleteAsync(code);
    }
}
