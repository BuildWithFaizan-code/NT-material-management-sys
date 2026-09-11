using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class MakersMasterService : IMakersMasterService
    {
        private readonly IMakersMasterRepository _repository;

        public MakersMasterService(IMakersMasterRepository repository)
        {
            _repository = repository;
        }

        public async Task<IEnumerable<MakersMasterDto>> GetAllAsync()
        {
            return await _repository.GetAllAsync();
        }

        public async Task<int> GetNextCodeAsync()
        {
            return await _repository.GetNextCodeAsync();
        }

        public async Task<bool> InsertAsync(MakersMasterDto item)
        {
            return await _repository.InsertAsync(item);
        }

        public async Task<bool> UpdateAsync(MakersMasterDto item)
        {
            return await _repository.UpdateAsync(item);
        }

        public async Task<bool> DeleteAsync(int makerCode)
        {
            return await _repository.DeleteAsync(makerCode);
        }
    }
}
