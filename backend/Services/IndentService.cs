using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class IndentService : IIndentService
    {
        private readonly IIndentRepository _repository;
        private readonly ILogger<IndentService> _logger;

        public IndentService(IIndentRepository repository, ILogger<IndentService> logger)
        {
            _repository = repository ?? throw new ArgumentNullException(nameof(repository));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task<IndentLookupsDto> GetLookupsAsync()
        {
            return await _repository.GetLookupsAsync();
        }

        public async Task<List<IndentCostCenterLookupDto>> GetCostCentersByStoreAsync(int storeCode)
        {
            if (storeCode <= 0) return new List<IndentCostCenterLookupDto>();
            return await _repository.GetCostCentersByStoreAsync(storeCode);
        }

        public async Task<IndentPagedResult<IndentItemLookupDto>> SearchItemsAsync(string? search, int page, int pageSize)
        {
            return await _repository.SearchItemsAsync(search, page, pageSize);
        }

        public async Task<List<string>> GetRemarkSuggestionsAsync(string query)
        {
            return await _repository.GetRemarkSuggestionsAsync(query);
        }

        public async Task<bool> IsDateLockedAsync(DateTime date)
        {
            return await _repository.IsDateLockedAsync(date);
        }

        public async Task<IndentPagedResult<IndentHeaderDto>> GetIndentsAsync(IndentFilterRequest filter)
        {
            return await _repository.GetIndentsAsync(filter ?? new IndentFilterRequest());
        }

        public async Task<IndentHeaderDto?> GetIndentByCodeAsync(string indCode)
        {
            if (string.IsNullOrWhiteSpace(indCode)) return null;
            return await _repository.GetIndentByCodeAsync(indCode.Trim());
        }

        public async Task<string> SaveIndentAsync(IndentSaveRequest request, string username)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Authenticated user identity is required.", nameof(username));
            }

            if (request.IndDate == default)
            {
                throw new ArgumentException("A valid Indent Date is required.");
            }

            if (request.DeptCode <= 0)
            {
                throw new ArgumentException("Please select an Indenting Department.");
            }

            if (request.StoreCode <= 0)
            {
                throw new ArgumentException("Please select a Location / Store.");
            }

            if (request.Items == null || request.Items.Count == 0)
            {
                throw new InvalidOperationException("At least one line item is required to save an Indent.");
            }

            for (var i = 0; i < request.Items.Count; i++)
            {
                var item = request.Items[i];
                if (string.IsNullOrWhiteSpace(item.Code))
                {
                    throw new ArgumentException($"Item Code is required for line row #{i + 1}.");
                }
                if (item.Qty <= 0)
                {
                    throw new ArgumentException($"Quantity for line item #{i + 1} ({item.Code}) must be greater than zero.");
                }
                if (item.KhCode <= 0)
                {
                    throw new ArgumentException($"Cost Center is required for line item #{i + 1} ({item.Code}).");
                }
                if (item.TotalValue <= 0 && item.Rate > 0)
                {
                    item.TotalValue = Math.Round(item.Qty * item.Rate, 2);
                }
            }

            return await _repository.SaveIndentAsync(request, username);
        }

        public async Task<string> UpdateIndentAsync(string indCode, IndentSaveRequest request, string username)
        {
            if (string.IsNullOrWhiteSpace(indCode)) throw new ArgumentException("Indent Code is required.", nameof(indCode));
            if (request == null) throw new ArgumentNullException(nameof(request));
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Authenticated user identity is required.", nameof(username));
            }

            if (request.IndDate == default)
            {
                throw new ArgumentException("A valid Indent Date is required.");
            }

            if (request.DeptCode <= 0)
            {
                throw new ArgumentException("Please select an Indenting Department.");
            }

            if (request.StoreCode <= 0)
            {
                throw new ArgumentException("Please select a Location / Store.");
            }

            if (request.Items == null || request.Items.Count == 0)
            {
                throw new InvalidOperationException("At least one line item is required to save an Indent.");
            }

            for (var i = 0; i < request.Items.Count; i++)
            {
                var item = request.Items[i];
                if (string.IsNullOrWhiteSpace(item.Code))
                {
                    throw new ArgumentException($"Item Code is required for line row #{i + 1}.");
                }
                if (item.Qty <= 0)
                {
                    throw new ArgumentException($"Quantity for line item #{i + 1} ({item.Code}) must be greater than zero.");
                }
                if (item.TotalValue <= 0 && item.Rate > 0)
                {
                    item.TotalValue = Math.Round(item.Qty * item.Rate, 2);
                }
            }

            return await _repository.UpdateIndentAsync(indCode.Trim(), request, username);
        }

        public async Task<bool> DeleteIndentAsync(string indCode, string username)
        {
            if (string.IsNullOrWhiteSpace(indCode)) throw new ArgumentException("Indent Code is required.", nameof(indCode));
            if (string.IsNullOrWhiteSpace(username)) throw new ArgumentException("Authenticated user identity is required.", nameof(username));
            return await _repository.DeleteIndentAsync(indCode.Trim(), username);
        }
    }
}
