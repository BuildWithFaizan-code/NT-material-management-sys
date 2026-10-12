using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IPurchaseOrderRepository
    {
        Task<PurchaseOrderPagedResult<PurchaseOrderHeaderDto>> GetPurchaseOrdersAsync(PurchaseOrderFilterRequest filter);
        Task<PurchaseOrderHeaderDto?> GetPurchaseOrderByNoAsync(string poNo);
        Task<PurchaseOrderPagedResult<SupplierLookupDto>> GetSuppliersLookupAsync(string search, int page, int pageSize);
        Task<PurchaseOrderPagedResult<ItemLookupDto>> GetItemsLookupAsync(string search, int page, int pageSize);
        Task<List<ItemMergeLookupDto>> GetItemMergesAsync(string itemCode);
        Task<List<string>> GetShadesAsync();
        Task<PurchaseOrderLookupsDto> GetLookupsAsync();
        Task<bool> IsDateLockedAsync(DateTime poDate);
        Task<string> SavePurchaseOrderAsync(PurchaseOrderSaveRequest request, string username);
        Task<bool> DeletePurchaseOrderAsync(string poNo, string username);
    }
}
