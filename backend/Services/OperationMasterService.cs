using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class OperationMasterService : IOperationMasterService
    {
        private readonly IOperationMasterRepository _repository;

        public OperationMasterService(IOperationMasterRepository repository)
        {
            _repository = repository;
        }

        public async Task<IEnumerable<OperationMasterDto>> GetAllAsync()
        {
            return await _repository.GetAllAsync();
        }

        public async Task<OperationMasterDto?> GetByCodeAsync(int code)
        {
            return await _repository.GetByCodeAsync(code);
        }

        public async Task<int> GetNextCodeAsync()
        {
            return await _repository.GetNextCodeAsync();
        }

        public async Task<bool> CreateAsync(CreateOperationDto model)
        {
            return await _repository.CreateAsync(model);
        }

        public async Task<bool> UpdateAsync(int code, CreateOperationDto model)
        {
            return await _repository.UpdateAsync(code, model);
        }

        public async Task<bool> DeleteAsync(int code)
        {
            return await _repository.DeleteAsync(code);
        }
    }
}
