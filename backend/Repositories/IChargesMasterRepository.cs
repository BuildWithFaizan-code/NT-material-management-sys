using MMSERP.Api.Models;

namespace MMSERP.Api.Repositories
{
    public interface IChargesMasterRepository
    {
        Task<IEnumerable<ChargesMasterDto>> GetAllAsync(string? module, string? mode);
        Task<bool> SaveAllAsync(IEnumerable<ChargesMasterDto> items);
    }
}
