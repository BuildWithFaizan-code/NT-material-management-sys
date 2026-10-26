using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class IndentApprovalService : IIndentApprovalService
    {
        private readonly IIndentApprovalRepository _repository;

        public IndentApprovalService(IIndentApprovalRepository repository)
        {
            _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        }

        public async Task<IndentApprovalLookupsDto> GetLookupsAsync()
        {
            return await _repository.GetLookupsAsync();
        }

        public async Task<IEnumerable<IndentApprovalRecordDto>> GetRecordsAsync(
            DateTime? asOnDate,
            DateTime? fromDate,
            DateTime? toDate,
            string? statusFilter,
            string? indCode,
            int? deptCode,
            string? itemCode)
        {
            return await _repository.GetRecordsAsync(
                asOnDate, fromDate, toDate, statusFilter, indCode, deptCode, itemCode);
        }

        public async Task<bool> CheckDateLockAsync(DateTime approvalDate)
        {
            return await _repository.IsDateLockedAsync(approvalDate);
        }

        public async Task<IndentApprovalActionResult> ProcessApprovalBatchAsync(
            IndentApprovalActionRequest request,
            string username)
        {
            if (request == null || request.Items == null || request.Items.Count == 0)
            {
                return new IndentApprovalActionResult
                {
                    Success = false,
                    Message = "No indent items selected."
                };
            }

            return await _repository.ProcessApprovalBatchAsync(request, username);
        }
    }
}
