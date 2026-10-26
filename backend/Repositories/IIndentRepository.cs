using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IIndentRepository
    {
        Task<IndentLookupsDto> GetLookupsAsync();
        Task<List<IndentCostCenterLookupDto>> GetCostCentersByStoreAsync(int storeCode);
        Task<IndentPagedResult<IndentItemLookupDto>> SearchItemsAsync(string? search, int page, int pageSize);
        Task<List<string>> GetRemarkSuggestionsAsync(string query);
        Task<bool> IsDateLockedAsync(DateTime date);
        Task<IndentPagedResult<IndentHeaderDto>> GetIndentsAsync(IndentFilterRequest filter);
        Task<IndentHeaderDto?> GetIndentByCodeAsync(string indCode);
        Task<string> SaveIndentAsync(IndentSaveRequest request, string username);
        Task<string> UpdateIndentAsync(string indCode, IndentSaveRequest request, string username);
        Task<bool> DeleteIndentAsync(string indCode, string username);
    }
}
