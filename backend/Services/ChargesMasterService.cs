using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class ChargesMasterService : IChargesMasterService
    {
        private readonly IChargesMasterRepository _repository;

        public ChargesMasterService(IChargesMasterRepository repository)
        {
            _repository = repository;
        }

        public Task<IEnumerable<ChargesMasterDto>> GetAllAsync(string? module, string? mode)
        {
            return _repository.GetAllAsync(module, mode);
        }

        public Task<bool> SaveAllAsync(IEnumerable<ChargesMasterDto> items)
        {
            return _repository.SaveAllAsync(items);
        }
    }
}
