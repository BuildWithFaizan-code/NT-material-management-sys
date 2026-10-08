using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IBomFollowupRepository
    {
        Task<IEnumerable<BomFollowupDepartmentDto>> GetDepartmentsAsync();
        Task<IEnumerable<BomFollowupDivisionDto>> GetDivisionsAsync();
        Task<IEnumerable<BomFollowupOrderTypeDto>> GetOrderTypesAsync();
        Task<IEnumerable<BomFollowupRecordDto>> GetOpenRecordsAsync(DateTime asOnDate, int? departmentCode, int? divisionCode, string? orderType);
        Task<bool> IsDateLockedAsync(DateTime asOnDate);
        Task<int> CloseBomBatchAsync(List<string> bomIds, DateTime asOnDate, string username, string companyName);
    }
}
