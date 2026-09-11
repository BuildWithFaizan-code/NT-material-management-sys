using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class StoreMasterService : IStoreMasterService
    {
        private readonly IStoreMasterRepository _repository;

        public StoreMasterService(IStoreMasterRepository repository)
        {
            _repository = repository;
        }

        public Task<IEnumerable<StoreMaster>> GetAllAsync() => _repository.GetAllAsync();

        public Task<IEnumerable<LocationLookupDto>> GetLocationLookupAsync() => _repository.GetLocationLookupAsync();

        public Task<int> GetNextCodeAsync() => _repository.GetNextCodeAsync();

        public Task<bool> CreateAsync(StoreMaster model) => _repository.CreateAsync(model);

        public Task<bool> UpdateAsync(int code, StoreMaster model) => _repository.UpdateAsync(code, model);

        public Task<bool> DeleteAsync(int code) => _repository.DeleteAsync(code);
    }
}
