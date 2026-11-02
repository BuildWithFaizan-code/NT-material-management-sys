using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IIssueManagerRepository
    {
        Task<IssueManagerLookupsDto> GetLookupsAsync();
        Task<string> GetNextPreviewCodeAsync(DateTime date, string issueMode, string fromDeptName);
        Task<StockCatalogPagedResultDto> GetStockCatalogAsync(
            DateTime date, int sourceDept, int sourceStore, int sourceDiv, string? searchQuery, int page, int pageSize);
        Task<double> CheckStockAvailabilityAsync(
            DateTime date, string currentDocNo, string itemCode, string mrgNo, string grade, string shade,
            int sourceDept, int sourceStore, int sourceDiv, int uom);
        Task<bool> IsDateLockedAsync(DateTime date);
        Task<List<string>> GetRemarkSuggestionsAsync(string query);
        Task<IssueManagerPagedListDto> GetIssuesAsync(
            DateTime? fromDate, DateTime? toDate, string? searchQuery, string? issueMode, int page, int pageSize);
        Task<IssueManagerDetailDto?> GetIssueByCodeAsync(string issueCode);
        Task<IssueManagerSaveResultDto> CreateIssueAsync(
            IssueManagerCreateRequestDto request, string username, string locationTag, string companyName);
        Task<IssueManagerSaveResultDto> UpdateIssueAsync(
            string issueCode, IssueManagerCreateRequestDto request, string username, string locationTag, string companyName);
        Task<IssueManagerSaveResultDto> DeleteIssueAsync(
            string issueCode, string username, string companyName);
    }
}
