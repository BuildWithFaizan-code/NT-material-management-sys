using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IPurchaseOrderApprovalService
    {
        Task<PoApprovalLookupsDto> GetLookupsAsync();
        Task<IEnumerable<PoApprovalRecordDto>> GetRecordsAsync(PoApprovalFilterQuery filter);
        Task<bool> CheckDateLockAsync(DateTime date);
        Task<int> ExecuteStatusActionAsync(PoApprovalActionRequest request, string username);
    }
}
