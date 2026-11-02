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
    public class IssueManagerService : IIssueManagerService
    {
        private readonly IIssueManagerRepository _repository;
        private readonly IConfiguration _configuration;
        private readonly ILogger<IssueManagerService> _logger;

        public IssueManagerService(
            IIssueManagerRepository repository,
            IConfiguration configuration,
            ILogger<IssueManagerService> logger)
        {
            _repository = repository ?? throw new ArgumentNullException(nameof(repository));
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public Task<IssueManagerLookupsDto> GetLookupsAsync()
        {
            return _repository.GetLookupsAsync();
        }

        public Task<string> GetNextPreviewCodeAsync(DateTime date, string issueMode, string fromDeptName)
        {
            return _repository.GetNextPreviewCodeAsync(date, issueMode, fromDeptName);
        }

        public Task<StockCatalogPagedResultDto> GetStockCatalogAsync(
            DateTime date, int sourceDept, int sourceStore, int sourceDiv, string? searchQuery, int page, int pageSize)
        {
            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 200) pageSize = 50;
            return _repository.GetStockCatalogAsync(date, sourceDept, sourceStore, sourceDiv, searchQuery, page, pageSize);
        }

        public Task<double> CheckStockAvailabilityAsync(
            DateTime date, string currentDocNo, string itemCode, string mrgNo, string grade, string shade,
            int sourceDept, int sourceStore, int sourceDiv, int uom)
        {
            return _repository.CheckStockAvailabilityAsync(date, currentDocNo, itemCode, mrgNo, grade, shade, sourceDept, sourceStore, sourceDiv, uom);
        }

        public Task<bool> IsDateLockedAsync(DateTime date)
        {
            return _repository.IsDateLockedAsync(date);
        }

        public Task<List<string>> GetRemarkSuggestionsAsync(string query)
        {
            return _repository.GetRemarkSuggestionsAsync(query);
        }

        public Task<IssueManagerPagedListDto> GetIssuesAsync(
            DateTime? fromDate, DateTime? toDate, string? searchQuery, string? issueMode, int page, int pageSize)
        {
            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 150) pageSize = 25;
            return _repository.GetIssuesAsync(fromDate, toDate, searchQuery, issueMode, page, pageSize);
        }

        public Task<IssueManagerDetailDto?> GetIssueByCodeAsync(string issueCode)
        {
            if (string.IsNullOrWhiteSpace(issueCode)) return Task.FromResult<IssueManagerDetailDto?>(null);
            return _repository.GetIssueByCodeAsync(issueCode.Trim());
        }

        public async Task<IssueManagerSaveResultDto> CreateIssueAsync(IssueManagerCreateRequestDto request, string username)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.Lines == null || request.Lines.Count == 0)
                throw new InvalidOperationException("Issue Manager requires at least one line item.");

            if (string.IsNullOrWhiteSpace(username))
                throw new InvalidOperationException("User context is required for transaction auditing.");

            var locationTag = CompanyConfigHelper.ResolveLocationCode(_configuration);
            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);

            return await _repository.CreateIssueAsync(request, username, locationTag, companyName);
        }

        public async Task<IssueManagerSaveResultDto> UpdateIssueAsync(
            string issueCode, IssueManagerCreateRequestDto request, string username)
        {
            if (string.IsNullOrWhiteSpace(issueCode))
                throw new ArgumentException("Issue code is required.", nameof(issueCode));
            if (request == null)
                throw new ArgumentNullException(nameof(request));
            if (request.Lines == null || request.Lines.Count == 0)
                throw new InvalidOperationException("Issue Manager requires at least one line item.");
            if (string.IsNullOrWhiteSpace(username))
                throw new InvalidOperationException("User context is required for transaction auditing.");

            var locationTag = CompanyConfigHelper.ResolveLocationCode(_configuration);
            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);

            return await _repository.UpdateIssueAsync(issueCode.Trim(), request, username, locationTag, companyName);
        }

        public async Task<IssueManagerSaveResultDto> DeleteIssueAsync(string issueCode, string username)
        {
            if (string.IsNullOrWhiteSpace(issueCode))
                throw new ArgumentException("Issue code is required.", nameof(issueCode));
            if (string.IsNullOrWhiteSpace(username))
                throw new InvalidOperationException("User context is required for transaction auditing.");

            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);

            return await _repository.DeleteIssueAsync(issueCode.Trim(), username, companyName);
        }
    }
}
