using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class GradeMasterService : IGradeMasterService
    {
        private readonly IGradeMasterRepository _repository;

        public GradeMasterService(IGradeMasterRepository repository)
        {
            _repository = repository;
        }

        public Task<IEnumerable<GradeMasterDto>> GetAllAsync() => _repository.GetAllAsync();
        public Task<int> GetNextSrlAsync() => _repository.GetNextSrlAsync();
        public Task<bool> InsertAsync(GradeMasterDto item) => _repository.InsertAsync(item);
        public Task<bool> UpdateAsync(GradeMasterDto item) => _repository.UpdateAsync(item);
        public Task<bool> DeleteAsync(int gradeSrl) => _repository.DeleteAsync(gradeSrl);
    }
}
