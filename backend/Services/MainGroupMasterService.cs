using MMSERP.Api.Models;
using MMSERP.Api.Repositories;

namespace MMSERP.Api.Services
{
    public class MainGroupMasterService : IMainGroupMasterService
    {
        private readonly IMainGroupMasterRepository _repository;

        public MainGroupMasterService(IMainGroupMasterRepository repository)
        {
            _repository = repository;
        }

        public async Task<IEnumerable<MainGroupMasterDto>> GetAllAsync(string? searchTerm = null)
        {
            return await _repository.GetAllAsync(searchTerm);
        }

        public async Task<MainGroupMasterDto?> GetByCodeAsync(string wipCode)
        {
            if (string.IsNullOrWhiteSpace(wipCode)) return null;
            return await _repository.GetByCodeAsync(wipCode.Trim());
        }

        public async Task<bool> InsertAsync(MainGroupMasterDto dto)
        {
            if (dto == null || string.IsNullOrWhiteSpace(dto.WipCode) || string.IsNullOrWhiteSpace(dto.WipName))
            {
                return false;
            }

            dto.WipCode = dto.WipCode.Trim();
            dto.WipName = dto.WipName.Trim();
            dto.WipMode = string.IsNullOrWhiteSpace(dto.WipMode) ? "Regular" : dto.WipMode.Trim();

            return await _repository.InsertAsync(dto);
        }

        public async Task<bool> UpdateAsync(MainGroupMasterDto dto)
        {
            if (dto == null || string.IsNullOrWhiteSpace(dto.WipCode) || string.IsNullOrWhiteSpace(dto.WipName))
            {
                return false;
            }

            dto.WipCode = dto.WipCode.Trim();
            dto.WipName = dto.WipName.Trim();
            dto.WipMode = string.IsNullOrWhiteSpace(dto.WipMode) ? "Regular" : dto.WipMode.Trim();

            return await _repository.UpdateAsync(dto);
        }

        public async Task<bool> DeleteAsync(string wipCode)
        {
            if (string.IsNullOrWhiteSpace(wipCode)) return false;
            return await _repository.DeleteAsync(wipCode.Trim());
        }

        public async Task<string> GetNextCodeAsync()
        {
            return await _repository.GetNextCodeAsync();
        }
    }
}
