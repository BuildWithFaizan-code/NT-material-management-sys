using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class OperatorMasterService : IOperatorMasterService
    {
        private readonly IOperatorMasterRepository _repository;

        public OperatorMasterService(IOperatorMasterRepository repository)
        {
            _repository = repository;
        }

        public async Task<IEnumerable<DepartmentDto>> GetDepartmentsAsync()
        {
            return await _repository.GetDepartmentsAsync();
        }

        public async Task<IEnumerable<OperatorMasterDto>> GetAllAsync()
        {
            return await _repository.GetAllAsync();
        }

        public async Task<OperatorMasterDto?> GetByCodeAsync(int code)
        {
            return await _repository.GetByCodeAsync(code);
        }

        public async Task<int> GetNextCodeAsync()
        {
            return await _repository.GetNextCodeAsync();
        }

        public async Task<bool> CreateAsync(CreateOperatorDto model)
        {
            return await _repository.CreateAsync(model);
        }

        public async Task<bool> UpdateAsync(int code, CreateOperatorDto model)
        {
            return await _repository.UpdateAsync(code, model);
        }

        public async Task<bool> DeleteAsync(int code)
        {
            return await _repository.DeleteAsync(code);
        }
    }
}
