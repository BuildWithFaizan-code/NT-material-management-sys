using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class FabricSizeMasterService : IFabricSizeMasterService
    {
        private readonly IFabricSizeMasterRepository _repository;

        public FabricSizeMasterService(IFabricSizeMasterRepository repository)
        {
            _repository = repository;
        }

        public Task<IEnumerable<FabricSizeMasterDto>> GetAllAsync()
        {
            return _repository.GetAllAsync();
        }

        public Task<int> GetNextCodeAsync()
        {
            return _repository.GetNextCodeAsync();
        }

        public Task<bool> InsertAsync(FabricSizeMasterDto item)
        {
            return _repository.InsertAsync(item);
        }

        public Task<bool> UpdateAsync(FabricSizeMasterDto item)
        {
            return _repository.UpdateAsync(item);
        }

        public Task<bool> DeleteAsync(int sizeCode)
        {
            return _repository.DeleteAsync(sizeCode);
        }
    }
}
