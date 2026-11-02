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
    public class StockTransferService : IStockTransferService
    {
        private readonly IStockTransferRepository _repository;
        private readonly IConfiguration _configuration;
        private readonly ILogger<StockTransferService> _logger;

        public StockTransferService(
            IStockTransferRepository repository,
            IConfiguration configuration,
            ILogger<StockTransferService> logger)
        {
            _repository = repository ?? throw new ArgumentNullException(nameof(repository));
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public Task<StockTransferLookupsDto> GetLookupsAsync(int? fromStoreId)
        {
            return _repository.GetLookupsAsync(fromStoreId);
        }

        public Task<string> GetNextIssueCodePreviewAsync(DateTime date, string issueMode)
        {
            return _repository.GetNextIssueCodePreviewAsync(date, issueMode);
        }

        public Task<List<StockTransferLookupItemDto>> GetToStoresAsync(int fromStoreId)
        {
            return _repository.GetToStoresAsync(fromStoreId);
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

        public Task<List<PendingRequisitionItemDto>> GetPendingRequisitionsAsync(string? search)
        {
            return _repository.GetPendingRequisitionsAsync(search);
        }

        public Task<StockTransferPagedListDto> GetTransfersAsync(
            DateTime? fromDate, DateTime? toDate, string? searchQuery, string? issueMode, int page, int pageSize)
        {
            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 150) pageSize = 25;
            return _repository.GetTransfersAsync(fromDate, toDate, searchQuery, issueMode, page, pageSize);
        }

        public Task<StockTransferDetailDto?> GetTransferByCodeAsync(string issueCode)
        {
            if (string.IsNullOrWhiteSpace(issueCode)) return Task.FromResult<StockTransferDetailDto?>(null);
            return _repository.GetTransferByCodeAsync(issueCode.Trim());
        }

        public async Task<StockTransferSaveResultDto> CreateTransferAsync(StockTransferCreateRequestDto request, string username)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.Lines == null || request.Lines.Count == 0)
                throw new InvalidOperationException("Stock transfer requires at least one row item.");

            if (string.IsNullOrWhiteSpace(username))
                throw new InvalidOperationException("User context is required for transaction auditing.");

            var locationTag = CompanyConfigHelper.ResolveLocationCode(_configuration);
            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);

            return await _repository.CreateTransferAsync(request, username, locationTag, companyName);
        }

        public async Task<StockTransferSaveResultDto> UpdateTransferAsync(
            string issueCode, StockTransferCreateRequestDto request, string username)
        {
            if (string.IsNullOrWhiteSpace(issueCode))
                throw new ArgumentException("Issue code is required.", nameof(issueCode));
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.Lines == null || request.Lines.Count == 0)
                throw new InvalidOperationException("Stock transfer requires at least one row item.");

            if (string.IsNullOrWhiteSpace(username))
                throw new InvalidOperationException("User context is required for transaction auditing.");

            var locationTag = CompanyConfigHelper.ResolveLocationCode(_configuration);
            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);

            return await _repository.UpdateTransferAsync(issueCode.Trim(), request, username, locationTag, companyName);
        }

        public async Task<StockTransferSaveResultDto> DeleteTransferAsync(string issueCode, string username)
        {
            if (string.IsNullOrWhiteSpace(issueCode))
                throw new ArgumentException("Issue code is required.", nameof(issueCode));

            if (string.IsNullOrWhiteSpace(username))
                throw new InvalidOperationException("User context is required for transaction auditing.");

            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);

            return await _repository.DeleteTransferAsync(issueCode.Trim(), username, companyName);
        }
    }
}
