using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class LocationMasterService : ILocationMasterService
    {
        private readonly ILocationMasterRepository _repository;

        public LocationMasterService(ILocationMasterRepository repository)
        {
            _repository = repository;
        }

        public async Task<IEnumerable<LocationMaster>> GetAllAsync()
        {
            return await _repository.GetAllAsync();
        }

        public async Task<LocationMaster?> GetByCodeAsync(int code)
        {
            return await _repository.GetByCodeAsync(code);
        }

        public async Task<int> GetNextCodeAsync()
        {
            return await _repository.GetNextCodeAsync();
        }

        public async Task<bool> CreateAsync(LocationMaster model)
        {
            if (string.IsNullOrWhiteSpace(model.LocName))
            {
                throw new ArgumentException("Location name is required.");
            }
            return await _repository.CreateAsync(model);
        }

        public async Task<bool> UpdateAsync(int code, LocationMaster model)
        {
            if (string.IsNullOrWhiteSpace(model.LocName))
            {
                throw new ArgumentException("Location name is required.");
            }
            return await _repository.UpdateAsync(code, model);
        }

        public async Task<bool> DeleteAsync(int code)
        {
            return await _repository.DeleteAsync(code);
        }
    }
}
