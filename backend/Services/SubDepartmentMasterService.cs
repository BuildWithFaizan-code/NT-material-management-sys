using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class SubDepartmentMasterService : ISubDepartmentMasterService
    {
        private readonly ISubDepartmentMasterRepository _repository;

        public SubDepartmentMasterService(ISubDepartmentMasterRepository repository)
        {
            _repository = repository;
        }

        public Task<IEnumerable<SubDepartmentMasterDto>> GetAllAsync()
            => _repository.GetAllAsync();

        public Task<SubDepartmentMasterDto?> GetByCodeAsync(int code)
            => _repository.GetByCodeAsync(code);

        public Task<int> GetNextCodeAsync()
            => _repository.GetNextCodeAsync();

        public Task<bool> CreateAsync(CreateSubDepartmentDto model)
            => _repository.CreateAsync(model);

        public Task<bool> UpdateAsync(int code, CreateSubDepartmentDto model)
            => _repository.UpdateAsync(code, model);

        public Task<bool> DeleteAsync(int code)
            => _repository.DeleteAsync(code);
    }
}
