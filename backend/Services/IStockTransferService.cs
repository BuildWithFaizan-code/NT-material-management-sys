using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IStockTransferService
    {
        Task<StockTransferLookupsDto> GetLookupsAsync(int? fromStoreId);
        Task<string> GetNextIssueCodePreviewAsync(DateTime date, string issueMode);
        Task<List<StockTransferLookupItemDto>> GetToStoresAsync(int fromStoreId);
        Task<StockCatalogPagedResultDto> GetStockCatalogAsync(
            DateTime date, int sourceDept, int sourceStore, int sourceDiv, string? searchQuery, int page, int pageSize);
        Task<double> CheckStockAvailabilityAsync(
            DateTime date, string currentDocNo, string itemCode, string mrgNo, string grade, string shade,
            int sourceDept, int sourceStore, int sourceDiv, int uom);
        Task<bool> IsDateLockedAsync(DateTime date);
        Task<List<string>> GetRemarkSuggestionsAsync(string query);
        Task<List<PendingRequisitionItemDto>> GetPendingRequisitionsAsync(string? search);
        Task<StockTransferPagedListDto> GetTransfersAsync(
            DateTime? fromDate, DateTime? toDate, string? searchQuery, string? issueMode, int page, int pageSize);
        Task<StockTransferDetailDto?> GetTransferByCodeAsync(string issueCode);
        Task<StockTransferSaveResultDto> CreateTransferAsync(StockTransferCreateRequestDto request, string username);
        Task<StockTransferSaveResultDto> UpdateTransferAsync(string issueCode, StockTransferCreateRequestDto request, string username);
        Task<StockTransferSaveResultDto> DeleteTransferAsync(string issueCode, string username);
    }
}
