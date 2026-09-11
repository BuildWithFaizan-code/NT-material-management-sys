using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IGroupMasterDefinitionService
    {
        Task<IEnumerable<GroupMasterDefinitionDto>> GetMappedDefinitionsAsync(string? mCode);
        Task<GroupMasterDefinitionDto?> GetByMsCodeAsync(string msCode);
        Task<IEnumerable<CategoryLookupDto>> GetCategoriesAsync();
        Task<IEnumerable<MainGroupLookupDto>> GetMainGroupsAsync();
        Task<string?> GetMainGroupNameByCodeAsync(string mCode);
        Task<bool> InsertAsync(GroupMasterDefinitionDto dto);
        Task<bool> UpdateAsync(GroupMasterDefinitionDto dto);
        Task<bool> DeleteAsync(string msCode);
    }
}
