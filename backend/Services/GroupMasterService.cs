using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class GroupMasterService : IGroupMasterService
    {
        private readonly IGroupMasterRepository _repository;

        public GroupMasterService(IGroupMasterRepository repository)
        {
            _repository = repository;
        }

        public Task<IEnumerable<GroupMasterDto>> GetAllAsync(string? searchQuery)
        {
            return _repository.GetAllAsync(searchQuery);
        }

        public Task<GroupMasterDto?> GetByCodeAsync(string code)
        {
            return _repository.GetByCodeAsync(code);
        }

        public Task<string> GetNextCodeAsync()
        {
            return _repository.GetNextCodeAsync();
        }

        public Task<IEnumerable<TaxSlabDto>> GetTaxSlabsAsync()
        {
            return _repository.GetTaxSlabsAsync();
        }

        public Task<bool> InsertAsync(GroupMasterDto item)
        {
            return _repository.InsertAsync(item);
        }

        public Task<bool> UpdateAsync(GroupMasterDto item)
        {
            return _repository.UpdateAsync(item);
        }

        public Task<bool> DeleteAsync(string code)
        {
            return _repository.DeleteAsync(code);
        }
    }
}
