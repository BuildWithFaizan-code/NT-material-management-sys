using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IPurchaseOrderApprovalRepository
    {
        Task<PoApprovalLookupsDto> GetLookupsAsync();
        Task<IEnumerable<PoApprovalRecordDto>> GetRecordsAsync(PoApprovalFilterQuery filter);
        Task<bool> CheckDateLockAsync(DateTime date);
        Task<int> ExecuteStatusActionAsync(PoApprovalActionRequest request, string username, string companyName);
    }
}
