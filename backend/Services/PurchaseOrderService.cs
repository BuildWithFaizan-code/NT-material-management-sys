using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class PurchaseOrderService : IPurchaseOrderService
    {
        private readonly IPurchaseOrderRepository _repo;
        private readonly ILogger<PurchaseOrderService> _logger;

        public PurchaseOrderService(IPurchaseOrderRepository repo, ILogger<PurchaseOrderService> logger)
        {
            _repo = repo ?? throw new ArgumentNullException(nameof(repo));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task<PurchaseOrderPagedResult<PurchaseOrderHeaderDto>> GetPurchaseOrdersAsync(PurchaseOrderFilterRequest filter)
        {
            return await _repo.GetPurchaseOrdersAsync(filter);
        }

        public async Task<PurchaseOrderHeaderDto?> GetPurchaseOrderByNoAsync(string poNo)
        {
            return await _repo.GetPurchaseOrderByNoAsync(poNo);
        }

        public async Task<PurchaseOrderPagedResult<SupplierLookupDto>> GetSuppliersLookupAsync(string search, int page, int pageSize)
        {
            return await _repo.GetSuppliersLookupAsync(search, page, pageSize);
        }

        public async Task<PurchaseOrderPagedResult<ItemLookupDto>> GetItemsLookupAsync(string search, int page, int pageSize)
        {
            return await _repo.GetItemsLookupAsync(search, page, pageSize);
        }

        public async Task<List<ItemMergeLookupDto>> GetItemMergesAsync(string itemCode)
        {
            return await _repo.GetItemMergesAsync(itemCode);
        }

        public async Task<List<string>> GetShadesAsync()
        {
            return await _repo.GetShadesAsync();
        }

        public async Task<PurchaseOrderLookupsDto> GetLookupsAsync()
        {
            return await _repo.GetLookupsAsync();
        }

        public async Task<bool> IsDateLockedAsync(DateTime poDate)
        {
            return await _repo.IsDateLockedAsync(poDate);
        }

        public async Task<string> SavePurchaseOrderAsync(PurchaseOrderSaveRequest request, string username)
        {
            if (request == null)
            {
                throw new ArgumentException("Purchase Order request payload is required.", nameof(request));
            }
            if (request.PCode <= 0)
            {
                throw new InvalidOperationException("Supplier / Party selection is required.");
            }
            if (request.Items == null || request.Items.Count == 0)
            {
                throw new InvalidOperationException("At least one line item is required to save a Purchase Order.");
            }
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Authenticated user identity is required.", nameof(username));
            }

            // Check date lock
            var isLocked = await _repo.IsDateLockedAsync(request.PoDate);
            if (isLocked)
            {
                _logger.LogWarning("PO save rejected: date {Date} is locked in LOCKDATAMST.", request.PoDate);
                throw new InvalidOperationException($"The date {request.PoDate:yyyy-MM-dd} is locked in financial data lock (LOCKDATAMST). Save rejected.");
            }

            try
            {
                var poNo = await _repo.SavePurchaseOrderAsync(request, username.Trim());
                _logger.LogInformation("Successfully saved Purchase Order '{PoNo}' by user {User}", poNo, username);
                return poNo;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error while saving Purchase Order");
                throw;
            }
        }

        public async Task<bool> DeletePurchaseOrderAsync(string poNo, string username)
        {
            if (string.IsNullOrWhiteSpace(poNo))
            {
                throw new ArgumentException("Purchase Order number is required.", nameof(poNo));
            }
            if (string.IsNullOrWhiteSpace(username))
            {
                throw new ArgumentException("Authenticated user identity is required.", nameof(username));
            }

            try
            {
                var success = await _repo.DeletePurchaseOrderAsync(poNo.Trim(), username.Trim());
                _logger.LogInformation("Purchase Order '{PoNo}' deleted by user {User}: {Success}", poNo, username, success);
                return success;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error while deleting Purchase Order '{PoNo}'", poNo);
                throw;
            }
        }
    }
}
