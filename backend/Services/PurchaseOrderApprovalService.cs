using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using MMSERP.Api.Common;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class PurchaseOrderApprovalService : IPurchaseOrderApprovalService
    {
        private readonly IPurchaseOrderApprovalRepository _repository;
        private readonly IConfiguration _configuration;
        private readonly ILogger<PurchaseOrderApprovalService> _logger;

        public PurchaseOrderApprovalService(
            IPurchaseOrderApprovalRepository repository,
            IConfiguration configuration,
            ILogger<PurchaseOrderApprovalService> logger)
        {
            _repository = repository;
            _configuration = configuration;
            _logger = logger;
        }

        public async Task<PoApprovalLookupsDto> GetLookupsAsync()
        {
            return await _repository.GetLookupsAsync();
        }

        public async Task<IEnumerable<PoApprovalRecordDto>> GetRecordsAsync(PoApprovalFilterQuery filter)
        {
            return await _repository.GetRecordsAsync(filter ?? new PoApprovalFilterQuery());
        }

        public async Task<bool> CheckDateLockAsync(DateTime date)
        {
            return await _repository.CheckDateLockAsync(date);
        }

        public async Task<int> ExecuteStatusActionAsync(PoApprovalActionRequest request, string username)
        {
            if (request == null || request.Items == null || request.Items.Count == 0)
            {
                throw new ArgumentException("At least one purchase order item must be selected.");
            }

            var isLocked = await _repository.CheckDateLockAsync(request.ApprovalDate);
            if (isLocked)
            {
                throw new InvalidOperationException($"The approval date '{request.ApprovalDate:yyyy-MM-dd}' is locked by management in LOCKDATAMST.");
            }

            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);
            return await _repository.ExecuteStatusActionAsync(request, username, companyName);
        }
    }
}
