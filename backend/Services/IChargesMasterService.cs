using MMSERP.Api.Models;

namespace MMSERP.Api.Services
{
    public interface IChargesMasterService
    {
        Task<IEnumerable<ChargesMasterDto>> GetAllAsync(string? module, string? mode);
        Task<bool> SaveAllAsync(IEnumerable<ChargesMasterDto> items);
    }
}
