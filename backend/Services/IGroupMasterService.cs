using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IGroupMasterService
    {
        Task<IEnumerable<GroupMasterDto>> GetAllAsync(string? searchQuery);
        Task<GroupMasterDto?> GetByCodeAsync(string code);
        Task<string> GetNextCodeAsync();
        Task<IEnumerable<TaxSlabDto>> GetTaxSlabsAsync();
        Task<bool> InsertAsync(GroupMasterDto item);
        Task<bool> UpdateAsync(GroupMasterDto item);
        Task<bool> DeleteAsync(string code);
    }
}
