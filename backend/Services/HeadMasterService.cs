using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class HeadMasterService : IHeadMasterService
    {
        private readonly IHeadMasterRepository _repository;

        public HeadMasterService(IHeadMasterRepository repository)
        {
            _repository = repository;
        }

        public Task<IEnumerable<HeadMasterDto>> GetAllAsync() => _repository.GetAllAsync();
        public Task<HeadMasterDto?> GetByCodeAsync(int code) => _repository.GetByCodeAsync(code);
        public Task<int> GetNextCodeAsync() => _repository.GetNextCodeAsync();
        public Task<bool> CreateAsync(CreateHeadMasterDto model) => _repository.CreateAsync(model);
        public Task<bool> UpdateAsync(int code, CreateHeadMasterDto model) => _repository.UpdateAsync(code, model);
        public Task<bool> DeleteAsync(int code) => _repository.DeleteAsync(code);
    }
}
