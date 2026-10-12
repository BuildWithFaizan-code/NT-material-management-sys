using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IPurchaseOrderAdvanceService
    {
        Task<IEnumerable<PoAdvancePartyLookupDto>> GetApprovedPoPartiesAsync();
        Task<IEnumerable<string>> GetApprovedPosForPartyAsync(int partyCode);
        Task<PoAdvanceHeaderDetailsDto?> GetPoHeaderDetailsAsync(string poNo, DateTime appDate);
        Task<IEnumerable<PoAdvanceHistoryRecordDto>> GetPoAdvanceHistoryAsync(string poNo);
        Task<IEnumerable<PoAdvanceHistoryRecordDto>> GetAllAdvancesAsync(string? searchQuery = null, int limit = 500);
        Task<IEnumerable<PoAdvancePartySummaryDto>> GetPartyAdvanceSummariesAsync(int partyCode);
        Task<bool> CheckDateLockAsync(DateTime date);
        Task<int> CreateAdvanceAsync(PoAdvanceCreateRequest request, string username);
        Task<bool> DeleteAdvanceAsync(int poId);
    }
}
