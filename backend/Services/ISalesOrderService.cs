using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface ISalesOrderService
    {
        Task<SalesOrderPagedResult<SalesOrderHeaderDto>> GetSalesOrdersAsync(SalesOrderFilterRequest filter);
        Task<SalesOrderHeaderDto?> GetSalesOrderByNoAsync(string soNo);
        Task<SalesOrderLookupsDto> GetLookupsAsync();
        Task<SalesOrderPagedResult<CustomerLookupDto>> GetCustomersLookupAsync(string search, int page, int pageSize);
        Task<SalesOrderPagedResult<SalesOrderItemLookupDto>> GetItemsLookupAsync(string search, int page, int pageSize);
        Task<List<string>> GetRemarksLookupAsync(string query);
        Task<bool> IsDateLockedAsync(DateTime date);
        Task<string> SaveSalesOrderAsync(SalesOrderSaveRequest request, string username);
        Task<bool> DeleteSalesOrderAsync(string soNo, string username);
    }
}
