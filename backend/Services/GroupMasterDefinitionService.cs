using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class GroupMasterDefinitionService : IGroupMasterDefinitionService
    {
        private readonly IGroupMasterDefinitionRepository _repository;

        public GroupMasterDefinitionService(IGroupMasterDefinitionRepository repository)
        {
            _repository = repository;
        }

        public Task<IEnumerable<GroupMasterDefinitionDto>> GetMappedDefinitionsAsync(string? mCode)
        {
            return _repository.GetMappedDefinitionsAsync(mCode);
        }

        public Task<GroupMasterDefinitionDto?> GetByMsCodeAsync(string msCode)
        {
            return _repository.GetByMsCodeAsync(msCode);
        }

        public Task<IEnumerable<CategoryLookupDto>> GetCategoriesAsync()
        {
            return _repository.GetCategoriesAsync();
        }

        public Task<IEnumerable<MainGroupLookupDto>> GetMainGroupsAsync()
        {
            return _repository.GetMainGroupsAsync();
        }

        public Task<string?> GetMainGroupNameByCodeAsync(string mCode)
        {
            return _repository.GetMainGroupNameByCodeAsync(mCode);
        }

        public Task<bool> InsertAsync(GroupMasterDefinitionDto dto)
        {
            return _repository.InsertAsync(dto);
        }

        public Task<bool> UpdateAsync(GroupMasterDefinitionDto dto)
        {
            return _repository.UpdateAsync(dto);
        }

        public Task<bool> DeleteAsync(string msCode)
        {
            return _repository.DeleteAsync(msCode);
        }
    }
}
