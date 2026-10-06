using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class BomService : IBomService
    {
        private readonly IBomRepository _repository;

        public BomService(IBomRepository repository)
        {
            _repository = repository;
        }

        public Task<string> GetNextBomIdAsync(string mode)
        {
            return _repository.GetNextBomIdAsync(mode);
        }

        public Task<IEnumerable<BomRecordSummaryDto>> GetAllSummariesAsync(string? mode = null, string? query = null)
        {
            return _repository.GetAllSummariesAsync(mode, query);
        }

        public Task<BomCompleteRecordDto?> GetByIdAsync(string bomId)
        {
            if (string.IsNullOrWhiteSpace(bomId)) return Task.FromResult<BomCompleteRecordDto?>(null);
            return _repository.GetByIdAsync(bomId.Trim());
        }

        public Task<string> SaveBomAsync(BomCompleteRecordDto record, string user = "SYSTEM")
        {
            if (record?.Header == null)
            {
                throw new ArgumentException("BOM Header payload cannot be null.");
            }

            if (string.IsNullOrWhiteSpace(record.Header.BomId))
            {
                throw new ArgumentException("BOM ID is required.");
            }

            if (string.IsNullOrWhiteSpace(record.Header.ICode))
            {
                throw new ArgumentException("Finished Good Material Code is required.");
            }

            return _repository.SaveBomAsync(record, user);
        }

        public Task<bool> DeleteBomAsync(string bomId, string user = "SYSTEM")
        {
            if (string.IsNullOrWhiteSpace(bomId)) return Task.FromResult(false);
            return _repository.DeleteBomAsync(bomId.Trim(), user);
        }

        public Task<IEnumerable<BomStoreLookupDto>> GetStoresAsync()
        {
            return _repository.GetStoresAsync();
        }

        public Task<IEnumerable<BomDepartmentLookupDto>> GetDepartmentsAsync()
        {
            return _repository.GetDepartmentsAsync();
        }

        public Task<IEnumerable<BomUnitLookupDto>> GetUnitsAsync()
        {
            return _repository.GetUnitsAsync();
        }

        public Task<IEnumerable<FinishedGoodLookupDto>> GetFinishedGoodsAsync(string skuCross = "", string query = "")
        {
            return _repository.GetFinishedGoodsAsync(skuCross, query);
        }

        public Task<IEnumerable<ComponentLookupDto>> GetComponentsAsync(string parentCode = "", string query = "")
        {
            return _repository.GetComponentsAsync(parentCode, query);
        }
    }
}
