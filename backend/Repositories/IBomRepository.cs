using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IBomRepository
    {
        Task<string> GetNextBomIdAsync(string mode);
        Task<IEnumerable<BomRecordSummaryDto>> GetAllSummariesAsync(string? mode = null, string? query = null);
        Task<BomCompleteRecordDto?> GetByIdAsync(string bomId);
        Task<string> SaveBomAsync(BomCompleteRecordDto record, string user = "SYSTEM");
        Task<bool> DeleteBomAsync(string bomId, string user = "SYSTEM");
        Task<IEnumerable<BomStoreLookupDto>> GetStoresAsync();
        Task<IEnumerable<BomDepartmentLookupDto>> GetDepartmentsAsync();
        Task<IEnumerable<BomUnitLookupDto>> GetUnitsAsync();
        Task<IEnumerable<FinishedGoodLookupDto>> GetFinishedGoodsAsync(string skuCross = "", string query = "");
        Task<IEnumerable<ComponentLookupDto>> GetComponentsAsync(string parentCode = "", string query = "");
    }
}
