using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IMaterialReturnRepository
    {
        Task<MaterialReturnLookupsDto> GetLookupsAsync();
        Task<string> GetNextPreviewCodeAsync(DateTime date, string retMode, string entityName);
        Task<MaterialReturnStockCatalogPagedResultDto> GetStockCatalogAsync(
            DateTime date, int deptCode, int storeId, int divId, string? searchQuery, int page, int pageSize);
        Task<double> CheckStockAvailabilityAsync(
            DateTime date, string currentDocNo, string itemCode, string mrgNo, string grade, string shade,
            int deptCode, int storeId, int divId, int uom);
        Task<bool> IsDateLockedAsync(DateTime date);
        Task<List<string>> GetRemarkSuggestionsAsync(string query);
        Task<MaterialReturnPagedListDto> GetReturnsAsync(
            DateTime? fromDate, DateTime? toDate, string? searchQuery, string? retMode, int page, int pageSize);
        Task<MaterialReturnDetailDto?> GetReturnByCodeAsync(string retCode);
        Task<MaterialReturnSaveResultDto> CreateReturnAsync(
            MaterialReturnCreateRequestDto request, string username, string locationTag, string companyName);
        Task<MaterialReturnSaveResultDto> UpdateReturnAsync(
            string retCode, MaterialReturnCreateRequestDto request, string username, string locationTag, string companyName);
        Task<MaterialReturnSaveResultDto> DeleteReturnAsync(
            string retCode, string username, string companyName);
    }
}
