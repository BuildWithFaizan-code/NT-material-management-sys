using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class CapitalConsumableMasterService : ICapitalConsumableMasterService
    {
        private readonly ICapitalConsumableMasterRepository _repository;

        public CapitalConsumableMasterService(ICapitalConsumableMasterRepository repository)
        {
            _repository = repository;
        }

        public Task<IEnumerable<CapitalConsumableMasterDto>> GetAllAsync() => _repository.GetAllAsync();
        public Task<int> GetNextCodeAsync() => _repository.GetNextCodeAsync();
        public Task<bool> InsertAsync(CapitalConsumableMasterDto item) => _repository.InsertAsync(item);
        public Task<bool> UpdateAsync(CapitalConsumableMasterDto item) => _repository.UpdateAsync(item);
        public Task<bool> DeleteAsync(int code) => _repository.DeleteAsync(code);
    }
}
