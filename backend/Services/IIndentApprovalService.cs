using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IIndentApprovalService
    {
        Task<IndentApprovalLookupsDto> GetLookupsAsync();

        Task<IEnumerable<IndentApprovalRecordDto>> GetRecordsAsync(
            DateTime? asOnDate,
            DateTime? fromDate,
            DateTime? toDate,
            string? statusFilter,
            string? indCode,
            int? deptCode,
            string? itemCode);

        Task<bool> CheckDateLockAsync(DateTime approvalDate);

        Task<IndentApprovalActionResult> ProcessApprovalBatchAsync(
            IndentApprovalActionRequest request,
            string username);
    }
}
