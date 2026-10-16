using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class SalesOrderService : ISalesOrderService
    {
        private readonly ISalesOrderRepository _repo;
        private readonly ILogger<SalesOrderService> _logger;

        public SalesOrderService(ISalesOrderRepository repo, ILogger<SalesOrderService> logger)
        {
            _repo = repo ?? throw new ArgumentNullException(nameof(repo));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task<SalesOrderPagedResult<SalesOrderHeaderDto>> GetSalesOrdersAsync(SalesOrderFilterRequest filter)
        {
            return await _repo.GetSalesOrdersAsync(filter);
        }

        public async Task<SalesOrderHeaderDto?> GetSalesOrderByNoAsync(string soNo)
        {
            if (string.IsNullOrWhiteSpace(soNo))
            {
                throw new ArgumentException("Sales Order number is required.", nameof(soNo));
            }
            return await _repo.GetSalesOrderByNoAsync(soNo.Trim());
        }

        public async Task<SalesOrderLookupsDto> GetLookupsAsync()
        {
            return await _repo.GetLookupsAsync();
        }

        public async Task<SalesOrderPagedResult<CustomerLookupDto>> GetCustomersLookupAsync(string search, int page, int pageSize)
        {
            return await _repo.GetCustomersLookupAsync(search, page, pageSize);
        }

        public async Task<SalesOrderPagedResult<SalesOrderItemLookupDto>> GetItemsLookupAsync(string search, int page, int pageSize)
        {
            return await _repo.GetItemsLookupAsync(search, page, pageSize);
        }

        public async Task<List<string>> GetRemarksLookupAsync(string query)
        {
            return await _repo.GetRemarksLookupAsync(query);
        }

        public async Task<bool> IsDateLockedAsync(DateTime date)
        {
            return await _repo.IsDateLockedAsync(date);
        }

        public async Task<string> SaveSalesOrderAsync(SalesOrderSaveRequest request, string username)
        {
            if (request == null)
            {
                throw new ArgumentException("Sales Order request payload is required.", nameof(request));
            }
            if (request.PCode <= 0)
            {
                throw new InvalidOperationException("Customer / Party selection is required.");
            }
            if (request.Items == null || request.Items.Count == 0)
            {
                throw new InvalidOperationException("At least one line item is required to save a Sales Order.");
            }
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Authenticated user identity is required.", nameof(username));
            }

            // Check date lock in LOCKDATAMST
            var isLocked = await _repo.IsDateLockedAsync(request.SoDate);
            if (isLocked)
            {
                _logger.LogWarning("Sales Order save rejected: date {Date} is locked in LOCKDATAMST.", request.SoDate);
                throw new InvalidOperationException($"The date {request.SoDate:yyyy-MM-dd} is locked in financial data lock (LOCKDATAMST). Save rejected.");
            }

            try
            {
                var soNo = await _repo.SaveSalesOrderAsync(request, username.Trim());
                _logger.LogInformation("Successfully saved Sales Order '{SoNo}' by user {User}", soNo, username);
                return soNo;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error while saving Sales Order");
                throw;
            }
        }

        public async Task<bool> DeleteSalesOrderAsync(string soNo, string username)
        {
            if (string.IsNullOrWhiteSpace(soNo))
            {
                throw new ArgumentException("Sales Order number is required.", nameof(soNo));
            }
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Authenticated user identity is required.", nameof(username));
            }

            try
            {
                var success = await _repo.DeleteSalesOrderAsync(soNo.Trim(), username.Trim());
                _logger.LogInformation("Sales Order '{SoNo}' deleted by user {User}: {Success}", soNo, username, success);
                return success;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error while deleting Sales Order '{SoNo}'", soNo);
                throw;
            }
        }
    }
}
