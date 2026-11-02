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
    public class MaterialReturnService : IMaterialReturnService
    {
        private readonly IMaterialReturnRepository _repository;
        private readonly IConfiguration _configuration;
        private readonly ILogger<MaterialReturnService> _logger;

        public MaterialReturnService(
            IMaterialReturnRepository repository,
            IConfiguration configuration,
            ILogger<MaterialReturnService> logger)
        {
            _repository = repository ?? throw new ArgumentNullException(nameof(repository));
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public Task<MaterialReturnLookupsDto> GetLookupsAsync()
        {
            return _repository.GetLookupsAsync();
        }

        public Task<string> GetNextPreviewCodeAsync(DateTime date, string retMode, string entityName)
        {
            return _repository.GetNextPreviewCodeAsync(date, retMode, entityName);
        }

        public Task<MaterialReturnStockCatalogPagedResultDto> GetStockCatalogAsync(
            DateTime date, int deptCode, int storeId, int divId, string? searchQuery, int page, int pageSize)
        {
            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 200) pageSize = 50;
            return _repository.GetStockCatalogAsync(date, deptCode, storeId, divId, searchQuery, page, pageSize);
        }

        public Task<double> CheckStockAvailabilityAsync(
            DateTime date, string currentDocNo, string itemCode, string mrgNo, string grade, string shade,
            int deptCode, int storeId, int divId, int uom)
        {
            return _repository.CheckStockAvailabilityAsync(date, currentDocNo, itemCode, mrgNo, grade, shade, deptCode, storeId, divId, uom);
        }

        public Task<bool> IsDateLockedAsync(DateTime date)
        {
            return _repository.IsDateLockedAsync(date);
        }

        public Task<List<string>> GetRemarkSuggestionsAsync(string query)
        {
            return _repository.GetRemarkSuggestionsAsync(query);
        }

        public Task<MaterialReturnPagedListDto> GetReturnsAsync(
            DateTime? fromDate, DateTime? toDate, string? searchQuery, string? retMode, int page, int pageSize)
        {
            if (page < 1) page = 1;
            if (pageSize < 1 || pageSize > 150) pageSize = 25;
            return _repository.GetReturnsAsync(fromDate, toDate, searchQuery, retMode, page, pageSize);
        }

        public Task<MaterialReturnDetailDto?> GetReturnByCodeAsync(string retCode)
        {
            if (string.IsNullOrWhiteSpace(retCode)) return Task.FromResult<MaterialReturnDetailDto?>(null);
            return _repository.GetReturnByCodeAsync(retCode.Trim());
        }

        public async Task<MaterialReturnSaveResultDto> CreateReturnAsync(MaterialReturnCreateRequestDto request, string username)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.Lines == null || request.Lines.Count == 0)
                throw new InvalidOperationException("Material return requires at least one line item.");
            if (string.IsNullOrWhiteSpace(username))
                throw new InvalidOperationException("User context is required for transaction auditing.");

            var locationTag = CompanyConfigHelper.ResolveLocationCode(_configuration);
            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);

            return await _repository.CreateReturnAsync(request, username, locationTag, companyName);
        }

        public async Task<MaterialReturnSaveResultDto> UpdateReturnAsync(string retCode, MaterialReturnCreateRequestDto request, string username)
        {
            if (string.IsNullOrWhiteSpace(retCode)) throw new ArgumentException("Return code is required.", nameof(retCode));
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (request.Lines == null || request.Lines.Count == 0)
                throw new InvalidOperationException("Material return requires at least one line item.");
            if (string.IsNullOrWhiteSpace(username))
                throw new InvalidOperationException("User context is required for transaction auditing.");

            var locationTag = CompanyConfigHelper.ResolveLocationCode(_configuration);
            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);

            return await _repository.UpdateReturnAsync(retCode.Trim(), request, username, locationTag, companyName);
        }

        public async Task<MaterialReturnSaveResultDto> DeleteReturnAsync(string retCode, string username)
        {
            if (string.IsNullOrWhiteSpace(retCode)) throw new ArgumentException("Return code is required.", nameof(retCode));
            if (string.IsNullOrWhiteSpace(username))
                throw new InvalidOperationException("User context is required for transaction auditing.");

            var companyName = CompanyConfigHelper.ResolveCompanyName(_configuration);

            return await _repository.DeleteReturnAsync(retCode.Trim(), username, companyName);
        }
    }
}
