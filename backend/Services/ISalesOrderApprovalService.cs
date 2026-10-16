using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface ISalesOrderApprovalService
    {
        Task<SoApprovalLookupsDto> GetLookupsAsync();
        Task<IEnumerable<SoApprovalRecordDto>> GetRecordsAsync(SoApprovalFilterQuery filter);
        Task<bool> CheckDateLockAsync(DateTime date);
        Task<int> ExecuteStatusActionAsync(SoApprovalActionRequest request, string username);
    }
}
